from baseagent import AgentParams, BaseAgent
from os import environ as env
from pydantic import BaseModel, Field
from pydantic_ai.providers.openai import OpenAIProvider
# from pydantic_ai.providers.mistral import MistralProvider
from pydantic_ai.providers.ollama import OllamaProvider
from pydantic_ai import RunContext
from typing import List, Optional, Union
from pydantic_ai.mcp import MCPServerStdio
from pydantic_ai.settings import ModelSettings
from Yagent import YOut
from Zagent import ZOut
from Uagent import UOut


class ScrutinizerDeps(BaseModel):
    votes: List
    prev: YOut | ZOut | UOut


class ScrutinizerOut(BaseModel):
    approved: bool
    critique: str


scrutinizer_provider = None

PROVIDER = env.get('LLM_PROVIDER', 'ollama')
LLM_PROVIDER_BASE_URL = env.get('LLM_PROVIDER_BASE', 'http://ollama-service:11434/v1')

match PROVIDER:
    case 'ollama':
        scrutinizer_provider = OllamaProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'openai':
        scrutinizer_provider = OpenAIProvider(base_url=LLM_PROVIDER_BASE_URL)

    # case 'mistral':
    #     api_key = env.get('LLM_API_KEY')
    #     scrutinizer_provider = MistralProvider(api_key=api_key)

    case _:
        raise ValueError(f'Unsupported LLM provider')


class ScrutinizerAgent(BaseAgent):
    def __init__(self):
        agent_p = AgentParams(
            model_name     = env.get('MODEL_NAME') ,
            deps_type      = ScrutinizerDeps                 ,
            out_type       = ScrutinizerOut                  ,
            model_provider = scrutinizer_provider            ,
            mcp_servers    = [MCPServerStdio(command='uvx', args=['duckduckgo-mcp-server'])],
            toolset        = [],
            model_settings = ModelSettings(
                extra_body = {
                    'truncate_prompt_tokens': int(env.get('TOKENS_TRUNCATION', 10000))
                }
            ),
        )

        super().__init__(agent_p=agent_p)

    def _get_sysprompt(self, ctx: RunContext[ScrutinizerDeps]) -> str:
        template = f''''
            Role: Senior Market Skeptic & Reality Auditor.
            Objective: You are the "Voice of the Customer" and the "Voice of the Wallet." Your job is to aggressively challenge the analyst's conclusion by comparing it against the raw user data and cold market facts. You must detect "AI-optimism," "corporate buzzwords," and "logical leaps."
            
            Input Data:
                The Ground Truth: Raw User Voice Clusters (The only thing that matters).
                The Analyst's Output: The proposed Y (Problem), Z (Competitor), or U (Unique Feature).
            
            Your Mission:
            Evaluate the output based on Practical Skepticism. Do not try to help the analyst. Try to find why their idea will fail in the real world.
            
            Scrutiny Guidelines:
                The "So What?" Test: Is the proposed Y/Z/U something a real person would actually pay money for, or is it just a "nice-to-have" theoretical concept?
                Logical Anchor: Did the analyst invent a sophisticated problem where users just wanted a "simple fix"? (e.g., Users want a working button, not an AI-powered touchless interface).
                Market Skepticism: If the analyst suggests something "revolutionary," check if people in this specific niche (parents, skaters, accountants) are actually conservative or price-sensitive.
            
            Reasoning Process (Chain of Thought):
                Independent Assessment: Look at the User Voices first. Form your own 5-second opinion.
                Web Verification: Search for "[Proposed Solution] failure" or "[Target Audience] behavior patterns."
                The "Reality Slap": Formulate a critique that acts as a corrective note (e.g., "Skaters care about durability, not social features").
            
            Few-Shot Examples of "Reality Check" Critique:
            
            Example 1: Validating Agent Y (Problem)
                User Voice: "The gym is always too crowded at 6 PM, I can't get to the bench."
                Analyst Y Output: "The problem (Y) is the lack of real-time AI load-balancing for fitness equipment."
                Scrutinizer Logic: Do people want 'load-balancing' or do they just want a gym that isn't overbooked?
                approved: False
                Critique: "Less optimism about high-tech solutions. People just want to work out without waiting. The problem is overcapacity and poor booking management, not a lack of AI."
            
            Example 2: Validating Agent U (Unique Feature)
                Context: Financial app for retirees.
                Analyst U Output: "Our 'U' is a gamified interface with NFT rewards for saving money."
                Scrutinizer Logic: Will a 70-year-old care about NFTs?
                approved: False
                Critique: "Know the audience. Retirees prioritize security, legibility, and trust. Gamification and NFTs will likely alienate this demographic rather than solve their problem."
            
            Example 3: Validating Agent Z (Competitor)
                Analyst Z Output: "The main competitor is Excel, which lacks automated data visualization."
                Scrutinizer Logic: Why do people still use Excel if it's 'bad'?
                approved: False
                Critique: "Excel isn't losing because it lacks 'visualization'—it's winning because it's free and everyone knows how to use it."

            User voices:
            {ctx.deps.votes}

            Previous agent analysis:
            {ctx.deps.prev}
        '''
        return template

    def _register_tools(self):
        pass


agent = ScrutinizerAgent()
