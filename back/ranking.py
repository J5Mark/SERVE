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
        matches = len(initiator_keywords & bus_keywords)
        score = matches / len(initiator_keywords & bus_keywords)
        score = matches / len(initiator_keywords) if initiator_keywords else 0
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

    if not bus_user:
        raise HTTPException(status_code=404, detail="User not found")

    if not bus_user.entrep:
        return []

    initiator_bios = [b.bio for b in bus_user.businesses if b.bio]
    initiator_bio_combined = " ".join(initiator_bios)

    if post_id:
        post = await db.get(Post, post_id)
        if post:
            initiator_bio_combined += f" {post.contents or ''}"
        else:
            pass

    result = await db.execute(
        select(Business)
        .options(selectinload(Business.communities), selectinload(Business.user))
        .where(Business.cont_goal.isnot(None))
        .where(Business.reaction_time.isnot(None))
        .where(Business.user_id != bus_user_id)
    )
    candidates = result.scalars().all()

    if not candidates:
        return []

    ranked = rank_entities(initiator_bio_combined, candidates)

    result = await db.execute(
        select(Connection.contact_id).where(Connection.requester_id == bus_user_id)
    )
    already_connected_ids = set(result.scalars().all())

    community_boost = 1.3

    scored = []
    for item in ranked:
        bus = item["bus"]

        if bus.user_id in already_connected_ids:
            continue

        result = await db.execute(
            select(func.count(Verification.id))
            .where(Verification.business_id == bus.id)
            .where(Verification.type == "seen")
        )
        seen_count = result.scalar() or 0

        result = await db.execute(
            select(func.count(Verification.id))
            .where(Verification.business_id == bus.id)
            .where(Verification.type == "used")
        )
        used_count = result.scalar() or 0

        result = await db.execute(
            select(func.count(Verification.id))
            .where(Verification.business_id == bus.id)
            .where(Verification.type == "coop")
        )
        coop_count = result.scalar() or 0

        verif_score = (coop_count * 3) + (used_count * 2) + (seen_count * 1)

        keyword_score = item["score"]

        is_same_community = any(c.id == community_id for c in bus.communities)
        final_score = keyword_score * (community_boost if is_same_community else 1)

        final_score += verif_score * 0.1

        scored.append(
            {
                "bus": bus,
                "score": final_score,
                "verification_stats": {
                    "seen_count": seen_count,
                    "used_count": used_count,
                    "coop_count": coop_count,
                },
            }
        )

    scored.sort(key=lambda x: x["score"], reverse=True)
    top_businesses = scored[:n]

    contacts = []
    for item in top_businesses:
        bus = item["bus"]
        user = bus.user

        contacts.append(
            BusinessContact(
                user_id=bus.user_id,
                username=user.username or "",
                phone_number=user.phone_number,
                business_name=bus.name,
                business_bio=bus.bio,
                cont_goal=bus.cont_goal,
                reaction_time=bus.reaction_time,
                verification_stats=item["verification_stats"],
            )
        )

    return contacts
