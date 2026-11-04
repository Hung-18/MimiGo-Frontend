# Mimi character atlas

`mimi_poses.png` is new reference-based artwork generated with the built-in
imagegen tool for the PO's mascot correction, 2026-11-05. It is not an original
standalone asset recovered from the supplied boards, and is pending PO visual
acceptance. No reference-board crop is shipped and no licensing approval is
inferred from the boards.

Source identity: `.mimigo/ui_reference/THIẾT KẾ GIAO DIỆN CÁC MÀN/Bảng thương hiệu MimiGo vui nhộn.png`.
The exact local review copy supplied to imagegen was
`reports/evidence/po_reference/26.png`. Supporting visual comparisons used
`06.png` (earlier brand variant) and `22.png` (Welcome) in that directory.
All these files were actually available. No standalone original PNG cutout,
SVG, layered character source, Rive or Lottie mascot was found in the repository.

The RGBA atlas is 1774 × 887, four columns × two rows, equal square cells.
Read row-major: idle, greeting, guide, thinking, correct, encourage, completion,
unused duplicate idle. Cell edges can lie on half-pixels; the Flutter consumer
uses proportional layout, preserving the atlas's exact 2:1 aspect ratio.
Transparent gutters isolate every pose. One cached decoded image is about 6 MiB;
there is no network asset, extra animation package or per-frame decoding.

Mimi's invariants: brown aviator cap, blue goggles with bronze rims, golden hair
tuft and antenna tips, glossy brown eyes, rosy cheeks, golden/dark-brown abdomen,
pink lotus wings and scarf/clasp, brown lotus backpack and boots. The new poses
use the same three-quarter front orientation. Only expression and gestures vary.
Flutter applies small rigid translation/rotation bursts; it never stretches the
face or wings. Existing accessibility, lifecycle and offscreen ticker guards stay
in force. This is pose-based animation, not a rigged wing/blink animation.

## Generation prompts

Built-in imagegen, reference input `26.png`, transparent background requested:

> Use case: identity-preserve. Create production character sprite sheet for MimiGo Flutter children's app based faithfully on the provided character identity board. Output transparent PNG 2048x1024 landscape, exact 4 columns x 2 rows of equal 512x512 cells. Each cell contains ONE full-body isolated Mimi, centered, same body/head scale and baseline, all appendages inside cell with ample transparent padding. No labels, text, tiles, backgrounds, logos or scenery. Cell positions row-major: 1 idle friendly neutral open eyes; 2 greeting smiling with raised waving hand; 3 guide kindly pointing to the right; 4 thinking hand at chin curious eyes; 5 correct joyful smile both hands lifted; 6 encourage gentle warm reassuring smile open welcoming hand; 7 completion delighted closed happy eyes arms celebrating; 8 repeat idle. Preserve exact distinctive original Mimi: cute golden yellow bee with round expressive face, huge glossy brown eyes and fine eyelashes, tiny orange nose, rosy cheeks, brown leather aviator cap and bronze-rimmed blue goggles ON TOP of head, curved brown antennae with yellow ball tips, small golden hair tuft, pink translucent lotus-petal wings with delicate veins, pink scarf with lotus clasp, brown leather backpack with pink lotus emblem, yellow/dark brown striped small abdomen and little brown boots. Polished soft dimensional children's storybook rendering matching supplied reference, warm shaded volume and fine highlights. Each pose is the SAME character in same three-quarter front orientation. Keep goggles, wing structure, face proportions, costume, colors identical across all 8 cells. Facial expressions and hand gestures change naturally without body deformation. Clean antialiased transparent edges, no cast background or extra symbols.

The tool returned 1774 × 887 rather than the requested dimensions. That is the
actual shipped size. First Android review exposed residual background haze;
a second built-in edit of the generated atlas used this prompt:

> Use case: background-extraction. Edit this exact sprite sheet ONLY remove the grey cream textured background haze and all rectangular backdrops and floor shadows to pure zero-alpha transparency. Keep every character pixel/pose/design/layout unchanged: same 4 columns 2 rows, 2:1 aspect, exact equal cells, same positions and scale. No cropping or moving characters. Preserve pink translucent lotus wings, fine antennae and costume edges with clean alpha. This is a transparent game atlas to composite on saturated colored app surfaces: ALL space between and around characters must be fully transparent alpha=0, with NO gray/white/color haze, NO boxes, NO shadows, NO gradient. Preserve all 8 characters unchanged.

The final output was copied into this repository. Original generated outputs
remain outside the repository under the tool's generated-images directory;
runtime depends only on this packaged atlas.
