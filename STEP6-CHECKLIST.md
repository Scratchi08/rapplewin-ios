# Step 6 checklist: polish

Effort: **S** = small (one sitting), **M** = medium, **L** = large.
`DECIDE` = needs a decision from you before I start.

## Done
- [x] Settings screen: display, computer (model and cards), keyboard type. Saved between launches.
- [x] Hardware keyboard on iPad: typing, arrows, Esc, Tab, Ctrl+letter
- [x] On-screen keyboard button; Backspace fixed
- [x] Keep 4:3 shape, smooth scaling, hide the control bar
- [x] iPad orientations
- [x] Hardcore switch (locks save states and hardware changes; red HC badge). Waiting on RetroAchievements approval.

## To do

### A. Display
1. Full-screen mode: hide the home indicator, run under the safe areas (S)
2. Integer scaling and overscan crop options (S)
3. Screenshot button, saved to Photos (S)
4. Metal CRT shader: curvature, bloom, phosphor glow (L) `DECIDE`
   The core already draws scanlines ("Half Scanlines"), so this is optional and could clash with it.

### B. iPad and iPhone layout
5. iPad landscape layout: larger picture with a side panel for controls (M)
6. On-screen joystick: size, opacity and position settings; bigger on iPad (M)
7. Test Split View and Stage Manager resizing (S)
8. iPhone portrait and landscape pass (iPhone 13), safe areas (S)
9. iPad keyboard shortcuts: Cmd+R reset, Cmd+D disks, Cmd+comma settings (S)

### C. Input
10. Open Apple and Closed Apple keys. Many programs need them; they act as joystick buttons 0 and 1 (S)
11. Analog joystick and paddle mode: the core has an "Analog Joypad" device; add an on-screen analog stick (M)
12. Mouse mode: Mouse Card, touch as mouse, mouse speed (M)
13. Button remapping screen: the core already has `applewin_joypad_*` options (M)
14. Key repeat when holding on-screen keys; Caps Lock handling (S)
15. Haptic feedback on virtual buttons (S)

### D. Sound and app lifecycle
16. Pause the emulator and audio when the app goes to the background or a call interrupts it (S) **recommended first**
17. Volume and mute control (S)
18. Auto-save when leaving the app (softcore only) `DECIDE` (M)

### E. Missing settings
19. Floppy multi-drive, playlist start disk, mouse speed (S)
20. Remember settings per disk (machine, colours) `DECIDE` (M)
21. Move the yellow joystick debug line and the RetroAchievements log into a "Developer" section (S)

### F. App finish
22. App icon, launch screen, display name (S) (I can draw a simple icon)
23. About screen: GPL notice, source link, AppleWin and rcheevos credits (S) **needed before sharing the app**
24. Accessibility labels for VoiceOver (S); translations (L, optional)

### G. Engineering
25. Replace my stand-in `libretro_min.h` with the official header (S)
26. Simulator build slice (M)
27. Cache the cloud build so it runs faster (S)

### H. Hardcore follow-ups (after RetroAchievements replies)
28. Contact RetroAchievements about emulator approval (you; I can draft the message)
29. Test a real hardcore unlock once approved (S)
30. Anything they require in review, such as extra restrictions (unknown)

## Suggested order
16 (pause on background) > 10 (Open Apple) > 23 (About screen) > 22 (icon) > 5 (iPad layout) > the rest.
