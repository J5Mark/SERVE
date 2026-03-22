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
    post: str
    votes: List
    critique: str | None = None


class YOut(BaseModel):
    Y: str
    reason: str = Field(description='Short and concise reasoning')


scrutinizer_provider = None

PROVIDER = env.get('LLM_PROVIDER', 'ollama')
LLM_PROVIDER_BASE_URL = env.get('LLM_PROVIDER_BASE', 'http://ollama-service:11434/v1')

match PROVIDER:
    case 'ollama':
        Y_provider = OllamaProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'openai':
        Y_provider = OpenAIProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'mistral':
        api_key = env.get('LLM_API_KEY')
        Y_provider = MistralProvider(api_key=api_key)

    case _:
        raise ValueError(f'Unsupported LLM provider')


class YAgent(BaseAgent):
    def __init__(self):
        agent_p = AgentParams(
            model_name     = env.get('MODEL_NAME') ,
            deps_type      = YDeps                 ,
            out_type       = YOut                  ,
            model_provider = Y_provider            ,
            # mcp_servers    = [MCPServerStdio(command='uvx', args=['duckduckgo-mcp-server'])],
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
            ### POST CONTENTS:
            {ctx.deps.post}

            ### VOTES UNDER POST:
            {votes_formatted}

            ## HARD RULES (STRICT)
            1. DO NOT invent new problems.
            2. DO NOT use metaphors, buzzwords, or abstract labels (e.g. "fragmentation tax", "paradigm shift").
            3. USE wording from users whenever possible.
            4. If multiple problems exist — pick ONLY ONE dominant problem.
            5. The problem must be concrete and observable in user behavior.
            
            ## SELECTION LOGIC
            1. Identify repeated or very similar complaints.
            2. Prefer:
               - highest frequency
               - strongest frustration (clear negative emotion, inconvenience, or loss)
            3. Ignore weak, vague, or one-off signals.
            
            ## TASK
            
            ### Step 1 — Extract candidate pains
            List 3–5 short pain statements directly based on user text.
            
            ### Step 2 — Select dominant pain
            Pick ONE pain that best represents the cluster.
            
            ### Step 3 — Define Y
            Rewrite it into a clear, simple problem statement:
            - one sentence
            - no abstraction
            - no invented terminology
            - must describe what the user struggles to do
            
            ### Step 4 — Classify loss
            Mark the primary loss:
            - time / money / status / comfort

            ## YOUR OUTPUT
            {YOut(Y='your hypiothesis', reason='your reasoning').model_dump_json()}
        """
        return template

    def _register_tools(self):
        pass


agent = YAgent()
