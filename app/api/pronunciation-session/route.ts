import { env } from "cloudflare:workers";

const OPENAI_REALTIME_URL = "https://api.openai.com/v1/realtime/calls";

function jsonError(message: string, status: number) {
  return Response.json({ error: message }, { status });
}

export async function POST(request: Request) {
  const apiKey = env.OPENAI_API_KEY ?? process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return jsonError("Realtime pronunciation is not configured yet.", 503);
  }

  const sdp = await request.text();
  if (!sdp.trim()) {
    return jsonError("Missing SDP offer.", 400);
  }

  const session = {
    type: "transcription",
    audio: {
      input: {
        transcription: {
          model: "gpt-4o-mini-transcribe",
          language: "en",
          prompt: "Expect one spoken English study word at a time from a vocabulary trainer.",
        },
        turn_detection: {
          type: "server_vad",
          threshold: 0.45,
          prefix_padding_ms: 240,
          silence_duration_ms: 420,
        },
        noise_reduction: {
          type: "near_field",
        },
      },
    },
    modalities: ["text"],
  };

  const formData = new FormData();
  formData.set("sdp", sdp);
  formData.set("session", JSON.stringify(session));

  const userId = request.headers.get("x-user-id")?.trim();
  const response = await fetch(OPENAI_REALTIME_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      ...(userId ? { "OpenAI-Safety-Identifier": `word-loop:${userId}` } : {}),
    },
    body: formData,
  });

  if (!response.ok) {
    const errorText = await response.text();
    return jsonError(
      errorText || "Failed to start realtime pronunciation session.",
      502,
    );
  }

  return new Response(await response.text(), {
    headers: {
      "Content-Type": "application/sdp",
    },
  });
}
