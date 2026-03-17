from clusterization import get_vote_clusters

async def get_post_analysis(post_data: dict) -> dict:

    post = Post.model_validate(post_data, from_attributes=True)
    clusters = get_vote_clusters(votes=post.votes)        

    
    
    return {
        "Y": "placeholder problem",
        "Z": "placeholder competitor",
        "U": "placeholder unique feature",
        "additional": "placeholder additional info"
    }
