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


class YDeps(BaseModel):
    pass


class YOut(BaseModel):
    pass


scrutinizer_provider = None

PROVIDER = env.get('LLM_PROVIDER', 'ollama')
LLM_PROVIDER_BASE_URL = env.get('LLM_PROVIDER_BASE', 'http://ollama-service:11434')

match PROVIDER:
    case 'ollama':
        scrutiniaer_provider = OllamaProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'openai':
        scrutiniaer_provider = OpenAIProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'mistral':
        api_key = env.get('LLM_API_KEY')
        scrutiniaer_provider = MistralProvider(api_key=api_key)

    case _:
        raise ValueError(f'Unsupported LLM provider')


class YAgent(BaseAgent):
    def __init__(self):
        agent_p = AgentParams()

        super().__init__(agent_p=agent_p)

    def _get_sysprompt(self, ctx: RunContext[YDeps]) -> str:
        pass


agent = YAgent()
