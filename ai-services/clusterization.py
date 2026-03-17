import numpy as np
import hdbscan
import math
from sklearn.metrics.pairwise import cosine_similarity
from typing import List, Dict, Any


def get_vote_clusters(votes: List, top_n_representative: int = 3) -> Dict[int, Any]:
    n = len(votes)
    if n < 10:
        return {0: votes} 

    embeddings = np.array([v.embedding for v in votes])

    dynamic_min_size = max(5, int(math.sqrt(n)))
    clusterer = hdbscan.HDBSCAN(
        min_cluster_size=dynamic_min_size,
        metric='euclidean',
        core_dist_n_jobs=6 
    )
    
    labels = clusterer.fit_predict(embeddings)

    refined_clusters = {}
    unique_labels = set(labels)

    for label in unique_labels:
        if label == -1:
            continue
        
        cluster_indices = np.where(labels == label)[0]
        cluster_embeddings = embeddings[cluster_indices]
        
        centroid = np.mean(cluster_embeddings, axis=0).reshape(1, -1)
        
        scores = cosine_similarity(cluster_embeddings, centroid).flatten()
        
        top_local_indices = scores.argsort()[-top_n_representative:][::-1]
        
        representative_samples = [votes[cluster_indices[i]] for i in top_local_indices]
        
        refined_clusters[int(label)] = representative_samples

    return refined_clusters    
