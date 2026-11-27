import robotsParser from "robots-parser";

export interface FetchResult { status: number; html: string; finalUrl: string }
export interface Fetcher { fetch(url: string): Promise<FetchResult> }

export class RobotsBlockedError extends Error {}

export function userAgent(contactEmail = process.env.TERMWATCH_CONTACT_EMAIL): string {
  if (!contactEmail) throw new Error("TERMWATCH_CONTACT_EMAIL is required: the user agent must carry a contact address");
  return `TermwatchBot/0.1 (+mailto:${contactEmail})`;
}

type Robots = ReturnType<typeof robotsParser>;

/** Plain HTTP fetcher: honours robots.txt (disallow and crawl-delay), identifies itself. */
export class HttpFetcher implements Fetcher {
  private robots = new Map<string, Robots | null>();
  private lastHit = new Map<string, number>();
  constructor(private ua: string, private timeoutMs = 30_000) {}

  private async robotsFor(origin: string): Promise<Robots | null> {
    if (this.robots.has(origin)) return this.robots.get(origin)!;
    let r: Robots | null = null;
    try {
      const res = await fetch(`${origin}/robots.txt`, { headers: { "user-agent": this.ua }, signal: AbortSignal.timeout(this.timeoutMs) });
      if (res.ok) r = robotsParser(`${origin}/robots.txt`, await res.text());
    } catch { /* no robots.txt reachable: treated as allow */ }
    this.robots.set(origin, r);
    return r;
  }

  /** Throws RobotsBlockedError if disallowed; otherwise waits out the crawl delay. */
  async assertAllowed(url: string): Promise<void> {
    const origin = new URL(url).origin;
    const robots = await this.robotsFor(origin);
    if (robots && robots.isAllowed(url, this.ua) === false) throw new RobotsBlockedError(`robots.txt disallows ${url}`);
    const delay = (robots?.getCrawlDelay(this.ua) ?? 1) * 1000;
    const wait = (this.lastHit.get(origin) ?? 0) + delay - Date.now();
    if (wait > 0) await new Promise((r) => setTimeout(r, wait));
    this.lastHit.set(origin, Date.now());
  }

  async fetch(url: string): Promise<FetchResult> {
    await this.assertAllowed(url);
    const res = await fetch(url, {
      headers: { "user-agent": this.ua, accept: "text/html,application/xhtml+xml" },
      redirect: "follow",
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    return { status: res.status, html: await res.text(), finalUrl: res.url };
  }
}

interface PwPage { goto(u: string, o: object): Promise<{ status(): number } | null>; content(): Promise<string>; url(): string }
interface PwBrowser { newContext(o: object): Promise<{ newPage(): Promise<PwPage> }>; close(): Promise<void> }
interface PwModule { chromium: { launch(): Promise<PwBrowser> } }

/** Fallback for JS-rendered pages. Requires the optional `playwright` package. */
export class PlaywrightFetcher implements Fetcher {
  constructor(private http: HttpFetcher, private ua: string) {}
  async fetch(url: string): Promise<FetchResult> {
    await this.http.assertAllowed(url);
    const name = "playwright";
    const pw = (await import(/* @vite-ignore */ name)) as PwModule;
    const browser = await pw.chromium.launch();
    try {
      const page = await (await browser.newContext({ userAgent: this.ua })).newPage();
      const resp = await page.goto(url, { waitUntil: "networkidle", timeout: 45_000 });
      return { status: resp?.status() ?? 0, html: await page.content(), finalUrl: page.url() };
    } finally {
      await browser.close();
    }
  }
}
