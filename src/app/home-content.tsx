"use client";

import Link from "next/link";
import { ArrowRight } from "lucide-react";

import { Navbar } from "@/components/navbar";

export function HomeContent() {
  return (
    <div className="bg-white dark:bg-black selection:bg-primary/10 selection:text-primary">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 bg-black dark:bg-white text-white dark:text-black px-4 py-2 text-sm font-medium"
      >
        Skip to main content
      </a>

      <Navbar />

      <main
        id="main-content"
        className="relative flex min-h-screen items-center justify-center overflow-hidden bg-white px-6 dark:bg-black"
      >
        <div className="absolute inset-0 bg-[linear-gradient(to_right,#f0f0f0_1px,transparent_1px),linear-gradient(to_bottom,#f0f0f0_1px,transparent_1px)] bg-[size:4rem_4rem] dark:bg-[linear-gradient(to_right,#18181b_1px,transparent_1px),linear-gradient(to_bottom,#18181b_1px,transparent_1px)]" />

        <section className="relative z-10 mx-auto flex w-full max-w-3xl flex-col items-center text-center">
          <p className="mb-6 text-sm font-medium uppercase tracking-[0.3em] text-muted-foreground">
            AgileKit
          </p>
          <h1 className="max-w-4xl text-5xl font-bold tracking-tighter text-gray-900 dark:text-white sm:text-6xl lg:text-7xl">
            Start a planning session.
          </h1>
          <p className="mt-6 max-w-xl text-lg leading-8 text-gray-600 dark:text-gray-400 sm:text-xl">
            Create a room, invite your team, and estimate.
          </p>

          <div className="mt-10 flex w-full max-w-sm flex-col gap-4 sm:max-w-none sm:flex-row sm:justify-center">
            <Link
              href="/room/new"
              className="inline-flex h-14 items-center justify-center gap-2 rounded-2xl bg-black px-8 text-base font-bold tracking-tight text-white transition-transform duration-200 hover:scale-105 dark:bg-white dark:text-black"
            >
              Start Session
              <ArrowRight className="h-4 w-4" />
            </Link>
            <Link
              href="/dashboard"
              className="inline-flex h-14 items-center justify-center rounded-2xl border border-gray-200 bg-white px-8 text-base font-semibold text-gray-900 transition-colors hover:bg-gray-50 dark:border-zinc-800 dark:bg-zinc-950 dark:text-white dark:hover:bg-zinc-900"
            >
              Open Dashboard
            </Link>
          </div>
        </section>
      </main>
    </div>
  );
}