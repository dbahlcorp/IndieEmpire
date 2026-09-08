# Employee animation sheets

Each employee is a 1024 x 1024 RGBA atlas divided into sixteen 256 x 256 frames.

| Rows | Frames |
| --- | --- |
| 1 | Four-frame walk cycle angled up/right |
| 2 | Four-frame walk cycle angled down/right |
| 3 | Four seated typing poses |
| 4 | Standing, coffee, talking, celebrating |

The first three identities are the original Classic Teal, Golden Creative, and Studio Blue sheets. Sheets D-L add Plum Logic, Rust Method, Copper Spark, Teal Focus, Silver Mentor, Violet Edge, Navy Craft, Olive Drive, and Coral Rise.

## Generation prompt

The nine new sheets used the built-in image generator with the original three sheets as strict visual references. The common final prompt requested one original employee in the same hand-painted 2.5D semi-chibi isometric style, exactly sixteen full-body poses in a 4 x 4 grid, consistent identity and clothing, safe transparent gutters, the established walk/work/reaction row order, and no furniture, text, scenery, overlap, or cropping. Each sheet supplied its own character description covering age, presentation, skin tone, hair or headwear, build, glasses/accessories, and clothing palette.

The generated backgrounds were then processed with a background-extraction prompt requiring genuine zero-alpha RGBA pixels while preserving every character, pose, shadow, and cell position. Finally, each complete alpha-connected pose was fitted into its corresponding 256 x 256 production cell with a 12 px safety gutter to prevent clipping and cross-cell bleeding.

### Character prompt additions

| Sheet | Character direction |
| --- | --- |
| D / Plum Logic | East Asian woman, early 30s, straight black bob, round teal glasses, plum cardigan, mint shirt, charcoal trousers, mustard sneakers |
| E / Rust Method | South Asian man, late 30s, friendly stocky build, wavy black hair, moustache, rectangular glasses, rust overshirt, cream tee, navy trousers |
| F / Copper Spark | White woman, late 20s, freckles, copper-red curly ponytail, forest bomber, muted gold shirt, indigo jeans, coral sneakers |
| G / Teal Focus | Middle Eastern woman, early 30s, deep-teal hijab, mustard cardigan, cream tunic, plum trousers, teal sneakers |
| H / Silver Mentor | Black woman, early 50s, sturdy build, silver-streaked locs, gold hoops, denim jacket, coral shirt, dark trousers |
| I / Violet Edge | White nonbinary person, mid-20s, ash-blond undercut, black ear stud, violet hoodie, teal tee, black jeans |
| J / Navy Craft | East Asian man, early 40s, salt-and-pepper side part, amber glasses, navy cardigan, cream collared shirt, burgundy trousers |
| K / Olive Drive | Latino man, early 30s, broad build, short dark curls and beard, olive overshirt, mustard tee, deep-teal trousers |
| L / Coral Rise | Black woman, early 20s, high braided bun, teal studs, coral hoodie, cream shirt, charcoal jeans, mustard high-tops |
