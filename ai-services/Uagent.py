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


class UDeps(BaseModel):
    votes: List
    critique: str | None = None


class UOut(BaseModel):
    U: str
    reason: str


scrutinizer_provider = None

PROVIDER = env.get('LLM_PROVIDER', 'ollama')
LLM_PROVIDER_BASE_URL = env.get('LLM_PROVIDER_BASE', 'http://ollama-service:11434/v1')

match PROVIDER:
    case 'ollama':
        U_provider = OllamaProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'openai':
        U_provider = OpenAIProvider(base_url=LLM_PROVIDER_BASE_URL)

    # case 'mistral':
    #     api_key = env.get('LLM_API_KEY')
    #     U_provider = MistralProvider(api_key=api_key)

    case _:
        raise ValueError(f'Unsupported LLM provider')


class UAgent(BaseAgent):
    def __init__(self):
        agent_p = AgentParams(
            model_name     = env.get('MODEL_NAME') ,
            deps_type      = UDeps                 ,
            out_type       = UOut                  ,
            model_provider = U_provider            ,
            mcp_servers    = [MCPServerStdio(command='uvx', args=['duckduckgo-mcp-server'])],
            toolset        = [],
            model_settings = ModelSettings(
                extra_body = {
                    'truncate_prompt_tokens': int(env.get('TOKENS_TRUNCATION', 10000))
                }
            ),
        )

        super().__init__(agent_p=agent_p)

    def _get_sysprompt(self, ctx: RunContext[UDeps]) -> str:
        template = f'''
            # SYSTEM PROMPT: AGENT U
            Focus: The 'U' variable (The Unique Experience/Feature).
            
            ## INPUT
            {ctx.deps.votes}
            
            ## YOUR TASK
            1. Based on the frustrations in the clusters, what is the ONE thing the user should feel or see that changes everything? 
            2. This is NOT about the backend tech (e.g., "better algorithms"). It is about the **Result** (e.g., "Food that arrives at exactly 4°C").
            3. Search for existing "best-in-class" experiences in adjacent industries to see if this "U" is achievable.
            
            ## EXAMPLE (Few-Shot)
            *User Voice:* "I want my delivery to actually be fresh, not just 'fast'."
            *Search:* "Innovative food packaging for temperature control," "Direct-to-consumer fresh logistics models."
            *Analysis:* The 'U' is "Guaranteed Thermal Integrity"—the customer receives a bowl that is crisp and chilled, perhaps via specialized 'Active-Cool' delivery containers, making the experience feel "Kitchen-to-Table" rather than "Courier-to-Door."
        '''
        return template

    def _register_tools(self):
        pass


agent = UAgent()
