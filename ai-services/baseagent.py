from pydantic_ai import Agent, RunContext, FunctionToolset, AgentRunResultEvent ToolDefinition, Tool
from pydantic_ai.models.openai import OpenAIChatModel
from pydantic_ai.providers.ollama import OllamaProvider
from pydantic.providers import Provider
from pydantic_ai.mcp import MCPServerSSE, MCPServerStdio
from pydantic import BaseModel, Field, ValidationError
from typing import List, Callable, Any
from abc import abstractmethod
from datetime import datetime
from pydantic_ai.messages import (
        FunctionToolCallEvent,
        FunctionToolResultEvent,
        PartStartEvent,
        PartDeltaEvent,
        ModelResponseStreamEvent,
    )
from pydantic_ai.settings import ModelSettings
from pydantic_ai.usage import UsageLimits
from pydantic_ai.exceptions import UsageLimitExceeded, ModelHTTPError, UnexpectedModelBehavior
import json, logging, inspect
import time, asyncio


logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s |  %(levelname)s | %(message)s',
)

logger = logging.getLogger()

class AgentParams(BaseModel):
    model_name     : str
    instructions   : str
    deps_type      : BaseModel | type | Any
    out_type       : BaseModel | type | Any
    model_provider : Provider
    mcp_servers    : List                 = Field(default=None)
    toolset        : List                 = Field(default=None)
    model_settings : ModelSettings | None = Field(default=None)
    usage_limits   : UsageLimits | None   = Field(default=None)

    class Config:
        arbitrary_types_allowed = True


class BaseAgent:
    def __init__(self, agent_p: AgentParams):
        self.logger = logging.getLogger()
        self.agent = None

        self._init_agent(agent_p)

    def _init_agent(self, agent_p: AgentParams):
        mcps = []
        self.toolset = [Tool(t) for t in agent_p.toolset]

        for mcp_s in agent_p.mcp_servers:
            try:
                self.logger.info(f'Initializing MCP server: {mcp_s.__repr__()}')
                mcp_serv = mcp_s
                if isinstance(mcp_s, str):
                    mcp_serv = MCPServerSSE(mcp_s)
                mcps.append(mcp_serv)
            except Exception as err:
                self.logger.error(f'Failed to initialize MCP server: {err}')
                raise

        try:
            self.logger.info('Initializing agent')
            self.agent = Agent(
                ubstructions = agent_p.instructions,
                deps_type = agent_p.deps_type,
                output_type = agent_p.out_type,
                toolsets = mcps,
                tools = self.toolset,
                model = OpenAIChatModel(
                    model_name = agent_p.model_name,
                    provider = agent_p.model_provider
                ),
                model_settings = agent_p.model_settings
            )            
        except Exception as err:
            self.logger.error(f'Failed to initialize agent: {err}')
            raise

        self.agent.system_prompt(self._get_sysprompt)
        self._register_tools()
        self.logger.info(self.toolset.__repr__())

    async def run(self, prompt: str, deps: Any, max_retries: int = 3) -> Any:
        for attempt in range(max_retries + 1):
            try:
                result = await self.agent.run(prompt, deps=deps, usage_limits=self.usage_limits)
                self.run_duration_hist.observe(duration)
                # usage = result.usage()
                return result.output
            except UnexpectedModelBehavior as e:
                self.logger.warning(f"Unexpected model behavior:\n\n{e}")
                if attempt == max_retries:
                    raise
                await asyncio.sleep(2 ** attempt)
            except UsageLimitExceeded as e:
                self.logger.warning(f"Agent exceeded usage limit!\n\n{e}")
                if attempt == max_retries:
                    raise
                await asyncio.sleep(2 ** attempt)
            except ModelHTTPError as e:
                self.logger.error("ModelHTTPError (attempt %d/%d): %s", attempt + 1, max_retries, e)
                if attempt == max_retries:
                    raise
                await asyncio.sleep(2 ** attempt)  # Exponential backoff
            except Exception as e:
                self.run_exceptions_counter.inc()
                self.logger.error("Agent run failed", {"error": str(e)})
                raise  


    @abstractmethod
    def _register_tools(self):
        pass

    @abstractmethod
    def _get_sysprompt(self, ctx: RunContext[Any]) -> str:
        pass
