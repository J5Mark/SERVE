import logging
from clusterization import get_vote_clusters
from schemas import Post
from nodes import get_Y, get_Z, get_U, criticise
from Yagent import YOut
from Zagent import ZOut
from Uagent import UOut

logger = logging.getLogger(__name__)

MAX_CRITIC_RETRIES = 2


async def get_post_analysis(post_data: dict, full_analysis: bool = True) -> dict:
    """
    Analyze a post's votes to extract Y (pain point), Z (competitor), U (unique feature).

    Always returns clustered votes. If full_analysis=True, also runs the agentic
    workflow with critic validation loops.
    """
    post = Post.model_validate(post_data, from_attributes=True)
    clusters = get_vote_clusters(votes=post.votes)

    all_votes = [v for cluster_votes in clusters.values() for v in cluster_votes]

    result = {
        "clusters": clusters,
        "vote_count": len(post.votes),
        "cluster_count": len(clusters),
    }

    if not full_analysis:
        logger.info("Returning clustered votes only (full_analysis=False)")
        return result

    logger.info(
        f"Running full analysis on {len(all_votes)} votes across {len(clusters)} clusters"
    )

    y_result = await _run_agent_with_critique(all_votes, get_Y, "Y", YOut)
    z_result = await _run_agent_with_critique(all_votes, get_Z, "Z", ZOut)
    u_result = await _run_agent_with_critique(all_votes, get_U, "U", UOut)

    result.update(
        {
            "Y": y_result["analysis"],
            "Y_reason": y_result["reason"],
            "Z": z_result["analysis"],
            "Z_reason": z_result["reason"],
            "U": u_result["analysis"],
            "U_reason": u_result["reason"],
        }
    )

    return result


async def _run_agent_with_critique(
    votes: list, agent_fn, letter: str, out_type, max_retries: int = MAX_CRITIC_RETRIES
) -> dict:
    """
    Run an agent (Y, Z, or U) with critic validation loop.
    Retries up to max_retries times if critic rejects the output.
    """
    critique = None

    for attempt in range(max_retries + 1):
        try:
            logger.info(
                f"Running {letter} agent (attempt {attempt + 1}/{max_retries + 1})"
            )

            analysis_result = await agent_fn(votes=votes, criticism=critique)

            if isinstance(analysis_result, out_type):
                analysis_str = (
                    analysis_result.Y
                    if hasattr(analysis_result, "Y")
                    else getattr(analysis_result, letter)
                )
                reason = analysis_result.reason
            else:
                analysis_str = str(analysis_result)
                reason = ""

            scrutiny = await criticise(votes=votes, prev=analysis_result, letter=letter)

            if scrutiny.approved:
                logger.info(f"{letter} agent approved by critic")
                return {"analysis": analysis_str, "reason": reason}

            logger.warning(f"{letter} agent rejected by critic: {scrutiny.critique}")
            critique = scrutiny.critique

        except Exception as e:
            logger.error(f"Error in {letter} agent (attempt {attempt + 1}): {e}")
            if attempt == max_retries:
                raise

    return {
        "analysis": analysis_str,
        "reason": reason,
        "status": "max_retries_exceeded",
    }
