// Heuristic safety screening. Keyword matching CANNOT catch every emergency;
// the UI always says so. Pure functions so they are unit-testable.

export type SafetyFlags = { emergency: boolean; selfHarm: boolean; matched: string[] };

const EMERGENCY_PATTERNS: [RegExp, string][] = [
  [/\b(can'?t|cannot|unable to|struggling to|hard to) breathe\b|severe(ly)? (short(ness)? of breath|breathing)|not breathing|choking|gasping/i, "breathing difficulty"],
  [/\b(severe|crushing|heavy|tight)\b.{0,20}\bchest (pain|pressure)|chest pain/i, "chest pain"],
  [/\bstroke\b|face (is )?droop|slurred speech|sudden (weakness|numbness)|one side of (my|the|his|her) (body|face)/i, "possible stroke signs"],
  [/\b(unconscious|passed out|fainted|unresponsive|loss of consciousness|not waking up|seizure)\b/i, "loss of consciousness or seizure"],
  [/\b(bleeding (heavily|a lot|won'?t stop|uncontrollably)|uncontrolled bleeding|severe bleeding|vomiting blood|coughing (up )?blood)\b/i, "severe bleeding"],
  [/\b(anaphyla|throat (is )?(closing|swelling)|swollen (tongue|throat))/i, "severe allergic reaction"],
  [/\b(overdose|poison(ed|ing)?)\b/i, "possible overdose or poisoning"],
  [/\bworst headache\b|thunderclap headache/i, "sudden severe headache"],
];

const SELF_HARM_PATTERNS = [
  /\b(kill(ing)? myself|end (my|it all)|suicid|self[- ]?harm|hurt(ing)? myself|want to die|don'?t want to (live|be alive)|cut(ting)? myself|no reason to live)\b/i,
];

export function screenMessage(text: string): SafetyFlags {
  const matched: string[] = [];
  for (const [re, label] of EMERGENCY_PATTERNS) if (re.test(text)) matched.push(label);
  const selfHarm = SELF_HARM_PATTERNS.some((re) => re.test(text));
  return { emergency: matched.length > 0, selfHarm, matched };
}

export type Severity = "mild" | "moderate" | "severe";
export type Duration = "hours" | "days" | "week" | "weeks";
export type CareLevel = "emergency" | "urgent" | "routine" | "self-care";

export function careGuidance(input: {
  severity: Severity;
  duration: Duration;
  redFlags: boolean;
  higherRisk: boolean;
}): CareLevel {
  if (input.redFlags) return "emergency";
  if (input.severity === "severe") return "urgent";
  if (input.severity === "moderate" && (input.higherRisk || input.duration === "weeks")) return "urgent";
  if (input.duration === "weeks" || input.duration === "week" || input.severity === "moderate" || input.higherRisk)
    return "routine";
  return "self-care";
}

export type Source = { n: number; title: string; slug: string; source_name: string; source_url: string; review_status: string; last_reviewed_at: string | null };

/** Return only sources the answer actually cites with [n] markers. */
export function citedSources(text: string, sources: Source[]): Source[] {
  const used = new Set<number>();
  for (const m of text.matchAll(/\[(\d{1,2})\]/g)) used.add(Number(m[1]));
  return sources.filter((s) => used.has(s.n));
}

