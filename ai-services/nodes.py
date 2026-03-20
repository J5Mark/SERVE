import json, sys, os, logging
from dataclasses import dataclass, field
from os import environ as env
from Yagent import agent as Ya, YDeps
from Zagent import agent as Za, ZDeps
from Uagent import agent as Ua, UDeps
from competition_scrutinizer import agent as critic, ScrutinizerDeps, ScrutinizerOut, YOut, ZOut, UOut
from typing import List, Dict, Literal, Any, Union
from datetime import datetime


async def get_Y(votes: List, criticism: str | None = None) -> YOut:
    d = YDeps(votes=votes, critique=criticism)
    analysis = await Ya.run("FOLLOW YOUR ROLE AND ANALYZE THE VOICES", deps=d)
    return analysis


async def get_Z(votes: List, criticism: str | None = None) -> ZOut:
    d = ZDeps(votes=votes, critique=criticism)
    analysis = await Za.run("FOLLOW YOUR ROLE AND ANALYZE THE VOICES", deps=d)
    return analysis


async def get_U(votes: List, criticism: str | None = None) -> UOut:
    d = UDeps(votes=votes, critique=criticism)
    analysis = await Ua.run("FOLLOW YOUR ROLE AND ANALYZE THE VOICES", deps=d)
    return analysis


async def criticise(
    votes: List, prev: Union[YOut, ZOut, UOut], letter: Literal["Y", "Z", "U"]
) -> ScrutinizerOut:
    cr_deps = ScrutinizerDeps(votes=votes, prev=prev)
    decision = await critic.run(
        f"FOLLOW YOUR ROLE AND DECIDE WHETHER THIS ANALYSIS OF {letter} PASSES",
        deps=cr_deps,
    )
    return decision
