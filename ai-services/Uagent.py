from baseagent import AgentParams, BaseAgent
from os import environ as env
from pydantic import BaseModel, Field
from pydantic_ai.providers.openai import OpenAIProvider
from pydantic_ai.providers.mistral import MistralProvider
from pydantic_ai.providers.ollama import OllamaProvider
from pydantic_ai import RunContext
from typing import List, Optional
from pydantic_ai.mcp import MCPServerStdio
from pydantic_ai.settings import ModelSettings


class UDeps(BaseModel):
    post: str
    votes: List
    critique: str | None = None


class UOut(BaseModel):
    U: str
    reason: str = Field(description='Short and concise reasoning')


scrutinizer_provider = None

PROVIDER = env.get('LLM_PROVIDER', 'ollama')
LLM_PROVIDER_BASE_URL = env.get('LLM_PROVIDER_BASE', 'http://ollama-service:11434/v1')

match PROVIDER:
    case 'ollama':
        U_provider = OllamaProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'openai':
        U_provider = OpenAIProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'mistral':
        api_key = env.get('LLM_API_KEY')
        U_provider = MistralProvider(api_key=api_key)

    case _:
        raise ValueError(f'Unsupported LLM provider')


class UAgent(BaseAgent):
    def __init__(self):
        agent_p = AgentParams(
            model_name     = env.get('MODEL_NAME') ,
            deps_type      = UDeps                 ,
            out_type       = UOut                  ,
            model_provider = U_provider            ,
            # mcp_servers    = [MCPServerStdio(command='uvx', args=['duckduckgo-mcp-server'])],
            toolset        = [],
            model_settings = ModelSettings(
                extra_body = {
                    'truncate_prompt_tokens': int(env.get('TOKENS_TRUNCATION', 10000))
                }
            ),
        )

        super().__init__(agent_p=agent_p)

    def _get_sysprompt(self, ctx: RunContext[UDeps]) -> str:
        votes_formatted = '\n'.join([f'competition: {v.competition}\n promblem: {v.problems}' for v in ctx.deps.votes])        
        template = f'''
            # SYSTEM PROMPT: AGENT U
            Focus: The 'U' variable (The Unique Experience/Feature).
            
            ## INPUT
            ### POST CONTENTS:
            {ctx.deps.post}

            ### VOTES UNDER POST:
            {votes_formatted}

            ## HARD RULES (STRICT)
            1. DO NOT mention technologies (AI, algorithms, backend, etc.).
            2. DO NOT invent futuristic or unrealistic experiences.
            3. DO NOT use metaphors or fancy names.
            4. MUST be directly connected to how users currently behave.
            5. MUST clearly improve or replace an existing behavior.
            
            ## CORE PRINCIPLE
            U is NOT a feature.
            
            U is:
            → what the user can do NOW that they could NOT do before
            OR
            → what they NO LONGER have to do
            
            ## TASK
            
            ### Step 1 — Identify current struggle
            Extract 1–2 key actions users currently perform with difficulty.
            
            ### Step 2 — Define improvement
            For each action, define:
            - what is removed, reduced, or simplified
            
            ### Step 3 — Define U
            Write ONE clear statement:
            - "instead of X, user can Y"
            - must be concrete and observable
            - must remove friction, not add complexity
            
            ### Step 4 — Describe user outcome
            Short description of what changes in user's experience:
            - faster / fewer steps / less thinking / less stress

            ## YOUR OUTPUT
            {UOut(U='your hypiothesis', reason='your reasoning').model_dump_json()}
        '''
        return template

    def _register_tools(self):
        pass


agent = UAgent()
