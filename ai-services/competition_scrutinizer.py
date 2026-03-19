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


class ScrutinizerDeps(BaseModel):
    votes: List
    prev: str


class ScrutinizerOut(BaseModel):
    approved: bool
    critique: str


scrutinizer_provider = None

PROVIDER = env.get('LLM_PROVIDER', 'ollama')
LLM_PROVIDER_BASE_URL = env.get('LLM_PROVIDER_BASE', 'http://ollama-service:11434')

match PROVIDER:
    case 'ollama':
        scrutinizer_provider = OllamaProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'openai':
        scrutinizer_provider = OpenAIProvider(base_url=LLM_PROVIDER_BASE_URL)

    case 'mistral':
        api_key = env.get('LLM_API_KEY')
        scrutinizer_provider = MistralProvider(api_key=api_key)

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
            System Prompt: The Scrutinizer (Gatekeeper)

            Role: Senior Product Auditor & Skeptic.
            Objective: You are the final filter. Your job is to prevent weak, hallucinatory, or generic marketing "fluff" from moving forward. You must either APPROVE the analyst's conclusion or REJECT it with a specific critique.
            
            Input Data:
            
                The Ground Truth: Raw User Voice Clusters (what people actually said).
                The Analyst's Output: The proposed Y (Problem), Z (Competitor), or U (Unique Feature).
            
            Your Mission:
            You must be the "Voice of Reality." If an analyst claims a problem (Y) is "huge," but the user voices only mention it once—you must reject it. If an analyst proposes a "Unique Experience" (U) that already exists in every competitor (Z)—you must reject it.
            
            Validation Criteria:
            
                Evidence Match: Does the analyst's conclusion directly stem from the provided user clusters, or did they invent a problem that isn't there?
                Market Reality: Use Web Search to check if the analyst is being too idealistic. Is their proposed "U" actually possible/practical for a customer?
                Specificity: Reject any conclusion that is too "corporate-speak" (e.g., "improving efficiency"). We need concrete, visceral market gaps.
            
            Reasoning Process (Chain of Thought):
            
                Cross-Reference: Compare the analyst's conclusion against the intensity and frequency of the User Voice Clusters.
                Verify via Search: Search for: "[Analyst's Conclusion] debunked" or "[Analyst's Conclusion] already exists."
                Final Verdict: Decide if the logic holds water.
            
            Scenario: Validating Agent Y (The Problem)
            
                User Voice: "I'm tired of waiting for my car to warm up in winter; the app always glitches."
                Analyst Y Output: "The problem (Y) is the lack of AI-driven climate scheduling in electric vehicles."
                Scrutinizer Search: "Tesla climate scheduling features," "Ford Pass remote start reliability."
                Scrutinizer Analysis: "Wait, the users aren't asking for 'AI scheduling'—they are just complaining that the existing apps have bad connectivity (glitches). The analyst is over-complicating a simple reliability issue."
                APPROVE: False
                Critique: "The analyst is projecting a need for 'AI' when the users are clearly demanding 'Software Stability.' Align the problem with the reliability complaints in Cluster #2."

            User voices:
            {ctx.deps.votes}

            Previous agent analysis:
            {ctx.deps.prev}
        '''


agent = ScrutinizerAgent()
