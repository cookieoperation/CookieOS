import { serve } from "bun"; // Or any minimal server

console.log("🍪 CookieOS Server Starting...");

const server = serve({
  port: 3000,
  fetch(req) {
    return new Response("CookieOS API Online");
  },
});

console.log(`🚀 Server running at http://localhost:${server.port}`);
