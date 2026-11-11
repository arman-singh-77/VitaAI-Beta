// Retrieval layer for RAG. v1 uses PostgreSQL full-text search via the
// `search_articles` RPC. To add embeddings later, implement another
// `Retriever` and swap it in `getRetriever()` — callers stay unchanged.
import { createPublicClient } from "./supabase-public.server";
import type { Source } from "./safety";

export type Passage = Source & { text: string };
export type Retriever = (query: string, limit?: number) => Promise<Passage[]>;

export const fullTextRetriever: Retriever = async (query, limit = 4) => {
  const sb = createPublicClient();
  const { data, error } = await sb.rpc("search_articles", { q: query.slice(0, 300), max_results: limit });
  if (error) throw new Error("Article search failed");
  return (data ?? []).map((a, i) => ({
    n: i + 1,
    title: a.title,
    slug: a.slug,
    source_name: a.source_name,
    source_url: a.source_url,
    review_status: a.review_status,
    last_reviewed_at: a.last_reviewed_at,
    text: `${a.summary}\n${a.body}`.slice(0, 1800),
  }));
};

export function getRetriever(): Retriever {
  return fullTextRetriever;
}

