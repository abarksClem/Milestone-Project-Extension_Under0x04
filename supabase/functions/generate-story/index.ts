import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import OpenAI from "https://esm.sh/openai@4.56.0";

const openai = new OpenAI({
  apiKey: Deno.env.get("OPENAI_API_KEY"),
});

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        {
          status: 405,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const { student, readingLevel, interest } = await req.json();

    if (!student || !readingLevel || !interest) {
      return new Response(
        JSON.stringify({
          error: "Missing required fields.",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const prompt = `
You are an elementary school literacy teacher.

Write ONE short children's story.

Student Name:
${student}

Reading Level:
${readingLevel}

Student Interest:
${interest}

Requirements:

- Safe for children.
- No violence.
- No scary themes.
- No romance.
- 120-180 words.
- Include several Dolch sight words naturally.
- Use vocabulary appropriate for the reading level.

After the story, generate:

1. Story title
2. Story
3. Dolch sight words used
4. Three comprehension questions

Return ONLY valid JSON.

Example format:

{
  "title":"...",
  "story":"...",
  "dolchWords":["...","..."],
  "questions":["...","...","..."]
}
`;

    const completion = await openai.chat.completions.create({
      model: "gpt-4.1-mini",
      temperature: 0.8,
      messages: [
        {
          role: "system",
          content:
            "You generate educational children's reading stories. Respond ONLY with valid JSON.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
    });

    const content = completion.choices[0].message.content;

    if (!content) {
      throw new Error("No response from OpenAI.");
    }

    let parsed;

    try {
      parsed = JSON.parse(content);
    } catch {
      return new Response(
        JSON.stringify({
          error: "AI returned invalid JSON.",
        }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
          },
        },
      );
    }

    return new Response(
      JSON.stringify(parsed),
      {
        headers: {
          "Content-Type": "application/json",
        },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({
        error: err.message,
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
        },
      },
    );
  }
});