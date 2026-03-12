"""
AloAgent — Always-on voice AI agent with screen awareness.
Uses xAI Grok realtime voice model + LiveKit Agents SDK.
"""
import logging
import os
from datetime import UTC, datetime

import aiohttp
import asyncio
from dotenv import load_dotenv
from livekit import rtc
from livekit.agents import (
    Agent,
    AgentServer,
    AgentSession,
    AudioConfig,
    BackgroundAudioPlayer,
    BuiltinAudioClip,
    ChatContext,
    JobContext,
    RunContext,
    ToolError,
    cli,
    inference,
    room_io,
    utils,
)
from livekit.agents.beta.tools import EndCallTool
from livekit.plugins import noise_cancellation, xai

logger = logging.getLogger("alo-agent")
load_dotenv(".env.local")

AGENT_NAME = "alo"

BRAVE_SEARCH_API_KEY = os.getenv("BRAVE_SEARCH_API_KEY", "")

SYSTEM_INSTRUCTIONS = """You are Alo — a sharp, reliable voice assistant for a solo founder.

# Personality
- Direct, no fluff. Executive BLUF style.
- Default language: Russian. Switch to English only for code/tech terms.
- Concise: 1-3 sentences unless depth is explicitly requested.
- Dry humor welcome. No hype, no filler.

# Voice output rules
- Plain text only. Never JSON, markdown, lists, tables, code, emojis.
- Spell out numbers, phone numbers, email addresses.
- Omit https:// when mentioning URLs.
- Avoid acronyms with unclear pronunciation.

# Capabilities
- Answer questions, explain topics, brainstorm ideas.
- Analyze what's on the user's screen in real-time when screen share is active.
- Search the web for current information when needed.
- Deep thinking/reasoning for complex problems — take time to reason through.

# Screen sharing
- When the user shares their screen, you receive a continuous video stream.
- You can see what they see in real-time.
- Proactively comment on what you see if relevant.
- When asked about the screen, describe what you currently observe.

# Conversational flow
- Prefer the simplest safe step first.
- Ask one question at a time.
- Summarize key results when closing a topic.
- When tools return data, summarize naturally — don't recite raw identifiers.

# Guardrails
- Stay within safe, lawful, appropriate use.
- For medical, legal, financial topics — general info only, suggest a professional.
- Protect privacy, minimize sensitive data exposure."""

GREETING_INSTRUCTIONS = """Greet the user briefly in Russian.
Say something like 'Привет! Ало на связи. Чем помочь?' — keep it short and natural."""


class AloAgent(Agent):
    def __init__(self) -> None:
        super().__init__(
            instructions=SYSTEM_INSTRUCTIONS,
            tools=[
                EndCallTool(
                    extra_description="End when user says goodbye or conversation is complete",
                    end_instructions="Скажи пользователю 'Пока! Если что — я на связи.' и заверши разговор.",
                    delete_room=False,
                ),
            ],
        )

    async def on_enter(self):
        await self.session.generate_reply(
            instructions=GREETING_INSTRUCTIONS,
            allow_interruptions=False,
        )

    @Agent.tool("web_search")
    async def web_search(self, ctx: RunContext, query: str) -> str:
        """Search the web for current information on any topic."""
        try:
            session = utils.http_context.http_session()
            timeout = aiohttp.ClientTimeout(total=15)
            resp = await session.get(
                "https://api.exa.ai/search",
                headers={
                    "x-api-key": "30d3ac18-b49c-4f44-b7db-19549d51a108",
                    "Content-Type": "application/json",
                },
                params={"query": query, "num_results": 5, "type": "neural"},
                timeout=timeout,
            )
            if resp.status != 200:
                return f"Search failed with status {resp.status}"
            data = await resp.json()
            results = data.get("results", [])
            if not results:
                return "No results found."
            summaries = []
            for r in results[:5]:
                title = r.get("title", "No title")
                url = r.get("url", "")
                text = r.get("text", "")[:200]
                summaries.append(f"{title}\n{url}\n{text}")
            return "\n\n".join(summaries)
        except Exception as e:
            logger.error(f"Web search error: {e}")
            return f"Search failed: {e}"

    @Agent.tool("brave_search")
    async def brave_search(self, ctx: RunContext, query: str) -> str:
        """Search the web using Brave Search for current information."""
        if not BRAVE_SEARCH_API_KEY:
            return "Brave Search API key not configured."
        try:
            session = utils.http_context.http_session()
            timeout = aiohttp.ClientTimeout(total=15)
            resp = await session.get(
                "https://api.search.brave.com/res/v1/web/search",
                headers={
                    "X-Subscription-Token": BRAVE_SEARCH_API_KEY,
                    "Accept": "application/json",
                },
                params={"q": query, "count": 5},
                timeout=timeout,
            )
            if resp.status != 200:
                return f"Brave search failed with status {resp.status}"
            data = await resp.json()
            results = data.get("web", {}).get("results", [])
            if not results:
                return "No results found."
            summaries = []
            for r in results[:5]:
                title = r.get("title", "No title")
                url = r.get("url", "")
                desc = r.get("description", "")[:200]
                summaries.append(f"{title}\n{url}\n{desc}")
            return "\n\n".join(summaries)
        except Exception as e:
            logger.error(f"Brave search error: {e}")
            return f"Search failed: {e}"

    @Agent.tool("deep_think")
    async def deep_think(self, ctx: RunContext, problem: str) -> str:
        """Think deeply about a complex problem using chain-of-thought reasoning."""
        thinker = inference.LLM(model="xai/grok-4-1-fast")
        think_ctx = ChatContext()
        think_ctx.add_message(
            role="system",
            content="Think step by step about this problem. Be thorough and analytical. Respond in Russian.",
        )
        think_ctx.add_message(role="user", content=problem)
        response = await thinker.chat(chat_ctx=think_ctx).collect()
        return response.text.strip() if response.text else "Не удалось проанализировать."


server = AgentServer(shutdown_process_timeout=60.0)


async def summarize_session(chat_ctx: ChatContext) -> str | None:
    """Generate end-of-call summary."""
    summary_ctx = ChatContext()
    summary_ctx.add_message(
        role="system",
        content="Summarize this conversation concisely in Russian. Highlight key topics and decisions.",
    )

    n_summarized = 0
    for item in chat_ctx.items:
        if item.type != "message":
            continue
        if item.role not in ("user", "assistant"):
            continue
        if item.extra.get("is_summary") is True:
            continue
        text = (item.text_content or "").strip()
        if text:
            summary_ctx.add_message(
                role="user",
                content=f"{item.role}: {text}",
            )
            n_summarized += 1

    if n_summarized == 0:
        logger.debug("No chat messages to summarize")
        return None

    summarizer = inference.LLM(model="xai/grok-4-1-fast")
    response = await summarizer.chat(chat_ctx=summary_ctx).collect()
    return response.text.strip() if response.text else None


async def on_session_end(ctx: JobContext) -> None:
    """Post-session: generate summary and optionally send to webhook."""
    ended_at = datetime.now(UTC)
    if not ctx._primary_agent_session:
        logger.error("No primary agent session for end-of-call processing")
        return

    report = ctx.make_session_report()
    summary = await summarize_session(report.chat_history)
    if not summary:
        logger.info("No summary generated")
        return

    logger.info(f"Session summary: {summary}")

    body = {
        "job_id": report.job_id,
        "room_id": report.room_id,
        "room": report.room,
        "started_at": (
            datetime.fromtimestamp(report.started_at, UTC)
            .isoformat()
            .replace("+00:00", "Z")
            if report.started_at
            else None
        ),
        "ended_at": ended_at.isoformat().replace("+00:00", "Z"),
        "summary": summary,
    }
    logger.info(f"Session report: {body}")


@server.rtc_session(agent_name=AGENT_NAME, on_session_end=on_session_end)
async def entrypoint(ctx: JobContext):
    session = AgentSession(
        llm=xai.realtime.RealtimeModel(voice="Eve"),
    )

    await session.start(
        agent=AloAgent(),
        room=ctx.room,
        room_options=room_io.RoomOptions(
            audio_input=room_io.AudioInputOptions(
                noise_cancellation=lambda params: (
                    noise_cancellation.BVCTelephony()
                    if params.participant.kind
                    == rtc.ParticipantKind.PARTICIPANT_KIND_SIP
                    else noise_cancellation.BVC()
                ),
            ),
            video_input=room_io.VideoInputOptions(
                enabled=True,
            ),
        ),
    )

    background_audio = BackgroundAudioPlayer(
        ambient_sound=AudioConfig(BuiltinAudioClip.FOREST_AMBIENCE, volume=0.3),
    )
    await background_audio.start(room=ctx.room, agent_session=session)


if __name__ == "__main__":
    cli.run_app(server)
