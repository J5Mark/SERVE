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


class ZDeps(BaseModel):
    post: str
    votes: List
    critique: str | None = None


class ZOut(BaseModel):
    Z: str
    reason: str = Field(description='Short and concise reasoning')


scrutinizer_provider = None

PROVIDER = env.get('LLM_PROVIDER', 'ollama')
LLM_PROVIDER_BASE_URL = env.get('LLM_PROVIDER_BASE', 'http://ollama-service:11434/v1')

match PROVIDER:
    case 'ollama':
        Z_provider = OllamaProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'openai':
        Z_provider = OpenAIProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'mistral':
        api_key = env.get('LLM_API_KEY')
        Z_provider = MistralProvider(api_key=api_key)

    case _:
        raise ValueError(f'Unsupported LLM provider')


class ZAgent(BaseAgent):
    def __init__(self):
        agent_p = AgentParams(
            model_name     = env.get('MODEL_NAME') ,
            deps_type      = ZDeps                 ,
            out_type       = ZOut                  ,
            model_provider = Z_provider            ,
            # mcp_servers    = [MCPServerStdio(command='uvx', args=['duckduckgo-mcp-server'])],
            toolset        = [],
            model_settings = ModelSettings(
                extra_body = {
                    'truncate_prompt_tokens': int(env.get('TOKENS_TRUNCATION', 10000))
                }
            ),
        )

        super().__init__(agent_p=agent_p)

    def _get_sysprompt(self, ctx: RunContext[ZDeps]) -> str:
        votes_formatted = '\n'.join([f'competition: {v.competition}\n promblem: {v.problems}' for v in ctx.deps.votes])        
        template = f'''
            # SYSTEM PROMPT: AGENT Z
            Focus: The 'Z' variable (The Current Alternatives).
            
            ## INPUT
            ### POST CONTENTS:
            {ctx.deps.post}

            ### VOTES UNDER POST:
            {votes_formatted}
            
            ## HARD RULES (STRICT)
            1. DO NOT explain industry reasons or "why companies failed".
            2. DO NOT use abstract labels or buzzwords.
            3. ONLY use solutions or behaviors mentioned or clearly implied by users.
            4. Prefer concrete actions over product names.
            5. If users describe a workaround — prioritize it over official products.
            
            ## SELECTION LOGIC
            1. Extract all mentioned ways users currently solve the problem.
            2. Separate:
               - tools/products (apps, platforms, brands)
               - behaviors/workarounds (manual steps, hacks, routines)
            3. Prefer the most:
               - frequent
               - painful (complex, repetitive, annoying)
            
            ## TASK
            
            ### Step 1 — Extract current solutions
            List 3–5 ways users currently deal with the problem.
            
            ### Step 2 — Select dominant alternative
            Pick ONE that best represents the "default behavior".
            
            ### Step 3 — Define Z
            Write a simple, concrete description:
            - one sentence
            - describes what users actually DO
            - no abstraction, no naming frameworks
            
            ### Step 4 — Optional context
            Mention tools ONLY if they are directly part of the behavior.

            ## YOUR OUTPUT
            {ZOut(Z='your hypiothesis', reason='your reasoning').model_dump_json()}
        '''
        return template

    def _register_tools(self):
        pass


agent = ZAgent()
