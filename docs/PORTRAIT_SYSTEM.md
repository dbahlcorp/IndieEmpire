# Modular employee portraits

Close-up employee portraits are composed at runtime from vector drawing primitives. No portrait texture is generated or saved per employee.

## Stable identity modules

- Face shape
- Hair style
- Hair colour
- Skin tone
- Glasses
- Clothing palette
- Facial hair
- Brow shape and eye spacing

`portrait_seed` deterministically selects the modules, so an employee keeps the same face through saves, promotions, and projects. An explicit or seed-selected office sprite rig constrains the available skin, hair, and clothing families; the close-up therefore remains visually connected to the character walking around the studio.

With the current module counts, the system supports far more combinations than the employee population can realistically exhaust while adding no per-employee texture memory.

## Added personality cues

- A small clothing pin is coloured by job discipline.
- High morale produces a smile.
- High stress overrides the smile with tense brows and mouth.
- Low morale produces a worried expression.
- Employee Detail uses a larger 104 px portrait while dense staff and hiring lists retain the compact 74 px version.

The expression layer is deliberately separate from identity: condition changes can affect how someone looks without changing who they are.
