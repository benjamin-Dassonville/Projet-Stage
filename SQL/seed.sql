-- =========================
-- EPI Control - Seed MVP
-- =========================

-- Nettoyage (optionnel mais pratique pour rejouer le seed)
delete from check_items;
delete from checks;
delete from role_equipment;
delete from equipment;
delete from roles;
delete from workers;
delete from teams;
delete from chefs;

-- Chefs
insert into chefs (id, name) values
  ('c1', 'Pierre'),
  ('c2', 'Alexandre');

-- Teams
insert into teams (id, name, chef_id) values
  ('1', 'Équipe 1', 'c2'),
  ('2', 'Équipe 2', 'c2');

-- Roles
insert into roles (id, label) values
  ('debroussailleur', 'Débroussailleur'),
  ('chantier', 'Chantier');

-- Equipment
insert into equipment (id, name) values
  ('botte', 'Bottes de sécurité'),
  ('casque', 'Casque'),
  ('gant', 'Gants'),
  ('visiere', 'Visière');

-- Mapping role -> équipements requis
insert into role_equipment (role_id, equipment_id) values
  ('debroussailleur', 'botte'),
  ('debroussailleur', 'casque'),
  ('debroussailleur', 'gant'),
  ('debroussailleur', 'visiere');

-- Workers (ids alignés avec ton ancien mock "team-worker")
insert into workers (id, team_id, name, employee_number, role, attendance, status, controlled)
values
  ('1-1', '1', 'Loïc Durant', '10001', 'debroussailleur', 'PRESENT', 'OK', false),
  ('1-2', '1', 'Jean Martin', '10002', 'debroussailleur', 'PRESENT', 'KO', false),
  ('1-3', '1', 'Paul Leroy', '10003', 'debroussailleur', 'ABS',     'OK', false),

  ('2-1', '2', 'Nadia Benali', '20001', 'debroussailleur', 'PRESENT', 'KO', false),
  ('2-2', '2', 'Sami Khelifi', '20002', 'debroussailleur', 'PRESENT', 'OK', false),
  ('2-3', '2', 'Inès Morel',   '20003', 'debroussailleur', 'PRESENT', 'OK', false);