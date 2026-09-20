-- Starting data, so the simulator has a rally, stages and crews to use.
-- Driver names are placeholders.

INSERT INTO rallies (name, year, country)
VALUES ('Acropolis Rally Greece', 2026, 'Greece');

INSERT INTO stages (rally_id, code, name, length_m)
SELECT id, 'SS1', 'Stage 1', NULL FROM rallies WHERE name = 'Acropolis Rally Greece' AND year = 2026;

INSERT INTO entries (rally_id, car, driver, co_driver, profile)
SELECT id, 'car-1', 'Driver A', 'Co-driver A', 'attacking' FROM rallies WHERE name = 'Acropolis Rally Greece' AND year = 2026
UNION ALL
SELECT id, 'car-2', 'Driver B', 'Co-driver B', 'smooth'    FROM rallies WHERE name = 'Acropolis Rally Greece' AND year = 2026;
