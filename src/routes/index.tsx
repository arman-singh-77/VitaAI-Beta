import { createFileRoute } from "@tanstack/react-router";
import { ShieldAlert, Leaf } from "lucide-react";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "VitaAI — Your Personal Health Assistant" },
      { name: "description", content: "Educational health information grounded in trusted sources like WHO and MedlinePlus." },
      { property: "og:title", content: "VitaAI — Your Personal Health Assistant" },
      { property: "og:description", content: "Educational health information grounded in trusted sources." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Index,
});

function Index() {
  return (
    <main className="min-h-screen bg-hero px-6 py-20">
      <div className="mx-auto max-w-3xl animate-rise">
        <div className="mb-8 flex items-center gap-2 text-lg font-semibold">
          <span className="grid h-9 w-9 place-items-center rounded-xl bg-brand text-primary-foreground">
            <Leaf className="h-5 w-5" aria-hidden />
          </span>
          VitaAI
        </div>
        <h1 className="font-display text-5xl leading-tight md:text-6xl">
          Calm, trusted answers <span className="text-brand">about your health.</span>
        </h1>
        <p className="mt-5 max-w-xl text-lg text-muted-foreground">
          Educational information grounded in a source-attributed library. The full dashboard, chat and library
          pages are being built.
        </p>
        <div className="card-surface mt-10 flex gap-3 p-5 text-sm">
          <ShieldAlert className="h-5 w-5 shrink-0 text-emergency" aria-hidden />
          <p>
            VitaAI is not a doctor or emergency service and cannot diagnose. In an emergency call your local
            emergency number (112 in India).
          </p>
        </div>
      </div>
    </main>
  );
}

