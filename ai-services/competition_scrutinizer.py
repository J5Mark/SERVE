from baseagent import AgentParams, BaseAgent
from os import environ as env
from pydantic import BaseModel, Field
from pydantic_ai.providers.openai import OpenAIProvider
from pydantic_ai.providers.mistral import MistralProvider
from pydantic_ai.providers.ollama import OllamaProvider
from pydantic_ai import RunContext
from typing import List, Optional, Union
from pydantic_ai.mcp import MCPServerStdio
from pydantic_ai.settings import ModelSettings
from Yagent import YOut
from Zagent import ZOut
from Uagent import UOut


class ScrutinizerDeps(BaseModel):
    post: str
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
            # mcp_servers    = [MCPServerStdio(command='uvx', args=['duckduckgo-mcp-server'])],
            toolset        = [],
            model_settings = ModelSettings(
                extra_body = {
                    'truncate_prompt_tokens': int(env.get('TOKENS_TRUNCATION', 10000))
                }
            ),
        )

        super().__init__(agent_p=agent_p)

    def _get_sysprompt(self, ctx: RunContext[ScrutinizerDeps]) -> str:
        votes_formatted = '\n'.join([f'competition: {v.competition}\n promblem: {v.problems}' for v in ctx.deps.votes])        
        
        template = f''''
            Role: Senior Market Skeptic & Reality Auditor.
            Objective: You are the "Voice of the Customer" and the "Voice of the Wallet." Your job is to aggressively challenge the analyst's conclusion by comparing it against the raw user data and cold market facts. You must detect "AI-optimism," "corporate buzzwords," and "logical leaps."
            
            Input Data:
                The Ground Truth: Raw User Voice Clusters (The only thing that matters).
                The Analyst's Output: The proposed Y (Problem), Z (Competitor), or U (Unique Feature).
            
            Your Mission:
            Evaluate the output based on Practical Skepticism. Do not try to help the analyst. Try to find why their idea will fail in the real world.
            
            ## HARD RULES
            1. DO NOT use web search.
            2. DO NOT explain markets or industries.
            3. DO NOT add new ideas.
            4. ONLY compare the analysis to user data.
            5. Be short, direct, and critical.
            
            ## CORE TASK
            Find mismatches between:
            - what users actually say
            - what the analysis claims
            
            ## FAILURE CONDITIONS (ANY = REJECT)
            
            1. NOT IN DATA  
               The analysis introduces ideas not present in user voices.
            
            2. OVER-ABSTRACTION  
               Uses buzzwords, metaphors, or vague concepts instead of concrete behavior.
            
            3. WRONG PRIORITY  
               Focuses on a minor issue while stronger pains exist in data.
            
            4. FAKE INNOVATION  
               Proposes something “fancy” when users clearly want a simple fix.
            
            5. NOT ACTIONABLE  
               Statement is too vague to build or verify.
            
            ## DECISION LOGIC
            
            - If ANY failure condition is triggered → approved = false  
            - Otherwise → approved = true
            
            ## TASK
            
            ### Step 1 — Quick scan
            Compare analysis to user voices.
            
            ### Step 2 — Detect violations
            List which failure conditions are triggered.
            
            ### Step 3 — Verdict
            Approve or reject.            Post contents:
            {ctx.deps.post}

            User voices:
            {votes_formatted}

            Previous agent analysis:
            {ctx.deps.prev}
            '''
        return template

    def _register_tools(self):
        pass


agent = ScrutinizerAgent()
