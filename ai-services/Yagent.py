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


class YDeps(BaseModel):
    votes: List
    critique: str | None = None


class YOut(BaseModel):
    Y: str
    reason: str


scrutinizer_provider = None

PROVIDER = env.get('LLM_PROVIDER', 'ollama')
LLM_PROVIDER_BASE_URL = env.get('LLM_PROVIDER_BASE', 'http://ollama-service:11434/v1')

match PROVIDER:
    case 'ollama':
        Y_provider = OllamaProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'openai':
        Y_provider = OpenAIProvider(base_url=LLM_PROVIDER_BASE_URL)

    # case 'mistral':
    #     api_key = env.get('LLM_API_KEY')
    #     Y_provider = MistralProvider(api_key=api_key)

    case _:
        raise ValueError(f'Unsupported LLM provider')


class YAgent(BaseAgent):
    def __init__(self):
        agent_p = AgentParams(
            model_name     = env.get('MODEL_NAME') ,
            deps_type      = YDeps                 ,
            out_type       = YOut                  ,
            model_provider = Y_provider            ,
            mcp_servers    = [MCPServerStdio(command='uvx', args=['duckduckgo-mcp-server'])],
            toolset        = [],
            model_settings = ModelSettings(
                extra_body = {
                    'truncate_prompt_tokens': int(env.get('TOKENS_TRUNCATION', 10000))
                }
            ),
        )

        super().__init__(agent_p=agent_p)

    def _get_sysprompt(self, ctx: RunContext[YDeps]) -> str:
        votes_formatted = '\n'.join([f'competition: {v.competition}\n promblem: {v.problems}' for v in ctx.deps.votes])        
        template = f"""
            # SYSTEM PROMPT: AGENT Y
            Focus: The 'Y' variable (The Pain Point).

            ## INPUT
            {votes_formatted}

            ## YOUR TASK
            1. Extract the underlying friction from the clusters. Is it a loss of time, money, status, or comfort?
            2. Search the web to see if this "Pain" is a documented market trend or a niche complaint.
            3. Define "Y" as a clear, high-stakes problem statement.
            
            ## EXAMPLE (Few-Shot)
            *User Voice:* "I'm tired of ordering 'healthy' salads that arrive soggy and warm after 40 minutes."
            *Search:* "Food delivery quality complaints 2024," "Salad shelf-life in transport," "Customer retention for healthy delivery."
            *Analysis:* The 'Y' isn't just "soggy salad"—it is the "Unreliability of fresh-food delivery," where the health benefit is negated by poor texture/temperature.
        """
        return template

    def _register_tools(self):
        pass


agent = YAgent()
