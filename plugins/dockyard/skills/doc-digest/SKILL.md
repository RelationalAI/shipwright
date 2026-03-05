---
name: doc-digest
description: Interactive document review — section-by-section walkthrough with context-aware analysis. Use when the user wants to review, walk through, digest, or critique any document.
---

# Doc Digest

Read the entire document into context. Split it into semantic sections that can each be read in about 30 seconds (~20-40 lines). Use natural boundaries: headings, topic shifts, logical breaks. Never split mid-paragraph or mid-code-block. For YAML/JSON, split on top-level keys or logical groupings.

Code files are not supported — use code-review instead.

If the document exceeds 2000 lines, warn the user and confirm before proceeding.

Tell the user how many sections you found, then begin.

## Review Loop

For each section:

1. Show **Section N of M: [Title]**
2. Present the section content verbatim with its original formatting. Render markdown as markdown, YAML/JSON in fenced code blocks.
3. After a horizontal rule, show your analysis:
   - **Summary:** 1-2 sentences on what this section covers and how it relates to the rest of the document.
   - **Problems** (only if found): inconsistencies with other sections, unclear language, missing information, flawed reasoning. Describe each problem plainly.
4. Ask: *"Any questions or feedback, or ready to move on?"*
5. Wait for the user's response before advancing.

If the user asks a question, answer it using the full document context, then ask if they want to move on. If they request an edit, apply it and confirm. If they share an observation, note it as feedback and move on.

## Wrap-up

After the last section, summarize the review: how many sections were reviewed, key issues found, and any feedback that was noted but not applied. Offer to apply noted feedback or revisit any section.
