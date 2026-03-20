from baseagent import AgentParams, BaseAgent
from os import environ as env
from pydantic import BaseModel, Field
from pydantic_ai.providers.openai import OpenAIProvider
# from pydantic_ai.providers.mistral import MistralProvider
from pydantic_ai.providers.ollama import OllamaProvider
from pydantic_ai import RunContext
from typing import List, Optional
from pydantic_ai.mcp import MCPServerStdio
from pydantic_ai.settings import ModelSettings


class ZDeps(BaseModel):
    votes: List
    critique: str | None = None


class ZOut(BaseModel):
    Z: str
    reason: str


scrutinizer_provider = None

PROVIDER = env.get('LLM_PROVIDER', 'ollama')
LLM_PROVIDER_BASE_URL = env.get('LLM_PROVIDER_BASE', 'http://ollama-service:11434/v1')

match PROVIDER:
    case 'ollama':
        Z_provider = OllamaProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'openai':
        Z_provider = OpenAIProvider(base_url=LLM_PROVIDER_BASE_URL)

    # case 'mistral':
    #     api_key = env.get('LLM_API_KEY')
    #     Z_provider = MistralProvider(api_key=api_key)

    case _:
        raise ValueError(f'Unsupported LLM provider')


class ZAgent(BaseAgent):
    def __init__(self):
        agent_p = AgentParams(
            model_name     = env.get('MODEL_NAME') ,
            deps_type      = ZDeps                 ,
            out_type       = ZOut                  ,
            model_provider = Z_provider            ,
            mcp_servers    = [MCPServerStdio(command='uvx', args=['duckduckgo-mcp-server'])],
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
            {votes_formatted}
            
            ## YOUR TASK
            1. Identify the "incumbent" solutions. This includes big brands, but also "DIY" fixes (e.g., "people just stop buying salads and cook at home").
            2. Search for the limitations of these incumbents. What are their reviews saying? Why haven't they fixed the problem yet?
            3. Define "Z" as the current standard that we are going to beat.
            
            ## EXAMPLE (Few-Shot)
            *Context:* High-end salad delivery.
            *Search:* "DoorDash salad reviews," "Sweetgreen delivery complaints," "Insulated packaging for cold delivery costs."
            *Analysis:* The 'Z' is "Standard Third-Party Delivery Apps." They fail because their logistics are general-purpose and don't prioritize temperature-sensitive greens.
        '''
        return template

    def _register_tools(self):
        pass


agent = ZAgent()
