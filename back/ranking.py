from sqlalchemy.orm import Session, selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, desc, case, func, or_, and_
from fastapi import HTTPException
from collections import defaultdict
from schemas import *
from postgres_conn import *


def extract_keywords(bio: str) -> set:
    stop_words = {"the", "and", "for", "with", "like", "of", "a", "can"}
    words = set(
        word.lower()
        for word in bio.split()
        if len(word) > 3 and word.lower() not in stop_words
    )
    return words


def rank_entities(initiator_bio: str, businesses: list) -> list[dict]:
    initiator_keywords = extract_keywords(initiator_bio)
    ranked = []
    for bus in businesses:
        bus_keywords = extract_keywords(bus.bio)
        intersection = initiator_keywords & bus_keywords
        matches = len(intersection)
        
        if matches == 0:
            score = 0
        elif not initiator_keywords:
            score = 0
        else:
            score = matches / len(intersection) * matches / len(initiator_keywords)
        
        ranked.append({"bus": bus, "score": score})
    return sorted(ranked, key=lambda x: x["score"], reverse=True)


async def fetch_useful_businessmen(
    n: int,
    bus_user_id: int,
    community_id: int,
    post_id: int,
    db: AsyncSession,
) -> list[BusinessContact]:
    result = await db.execute(
        select(User)
        .options(selectinload(User.businesses))
        .where(User.id == bus_user_id)
    )
    bus_user = result.scalars().first()
    
    if not bus_user or not bus_user.entrep:
        raise HTTPException(status_code=401, detail='User unable to request contacts')

    initiator_bios = [b.bio for b in bus_user.businesses if b.bio]
    initiator_bio = " ".join(initiator_bios)
    
    if post_id:
        post = await db.get(Post, post_id)
        if post and post.contents:
            initiator_bio += f" {post.contents}"

    result = await db.execute(
        select(Business)
        .options(
            selectinload(Business.user),
            selectinload(Business.communities),
        )
        .where(
            Business.cont_goal.isnot(None),
            Business.reaction_time.isnot(None),
            Business.user_id != bus_user_id,
        )
    )
    candidates = result.scalars().all()

    if not candidates:
        raise HTTPException(status_code=404, detail='No candidate businesses found')

    result = await db.execute(
        select(Connection.contact_id)
        .where(Connection.requester_id == bus_user_id)
    )
    already_connected = set(result.scalars().all())

    ranked = rank_entities(initiator_bio, candidates)

    verif_stats = {}
    result = await db.execute(
        select(
            Verification.business_id,
            Verification.type,
            func.count(Verification.id)
        )
        .where(Verification.type.in_(['seen', 'used', 'coop']))
        .group_by(Verification.business_id, Verification.type)
    )
    for bus_id, vtype, count in result.all():
        if bus_id not in verif_stats:
            verif_stats[bus_id] = {'seen': 0, 'used': 0, 'coop': 0}
        verif_stats[bus_id][vtype] = count

    scored = []
    for item in ranked:
        bus = item["bus"]
        
        if bus.user_id in already_connected:
            continue
            
        stats = verif_stats.get(bus.id, {'seen': 0, 'used': 0, 'coop': 0})
        verif_score = (stats['coop'] * 3) + (stats['used'] * 2) + stats['seen']
        
        community_boost = 1.3 if any(c.id == community_id for c in bus.communities) else 1
        final_score = item["score"] * community_boost + verif_score * 0.1
        
        scored.append({
            "bus": bus,
            "score": final_score,
            "verification_stats": stats,
        })

    scored.sort(key=lambda x: x["score"], reverse=True)
    top_n = scored[:n]

    contacts = [
        BusinessContact(
            user_id=item["bus"].user_id,
            username=item["bus"].user.username or "",
            phone_number=item["bus"].user.phone_number or "",
            business_name=item["bus"].name,
            business_bio=item["bus"].bio or "",
            cont_goal=item["bus"].cont_goal,
            reaction_time=item["bus"].reaction_time,
            verification_stats=item["verification_stats"],
        )
        for item in top_n
    ]
    
    return contacts
