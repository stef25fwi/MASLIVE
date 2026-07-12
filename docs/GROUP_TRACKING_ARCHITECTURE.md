# Architecture tracking groupe

```text
Tracker mobile
  -> position locale filtrée
  -> cadence adaptative 15 / 45 / 60 s
  -> group_positions/{groupId}/members/{uid}
  -> Cloud Function agrégée max 1 fois / 15 s
  -> filtre tracker-only + fallback admin
  -> pondération précision/âge + MAD + lissage
  -> group_admins/{adminUid}.averagePosition
  -> publication circuit si déplacement >=5 m ou heartbeat 30 s
```
