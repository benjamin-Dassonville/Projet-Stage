BEGIN;

INSERT INTO chefs(id, name)
VALUES
('chef_gestionnaire_de_paie', 'Gestionnaire de paie'),
('chef_philippe_grember', 'Philippe GREMBER'),
('chef_elodie_delesalle', 'Elodie DELESALLE'),
('chef_georges_d_haene', 'Georges D''HAENE'),
('chef_pierre_alexandre_huyghe', 'Pierre Alexandre HUYGHE'),
('chef_adelaide_gros', 'Adélaïde GROS'),
('chef_sylvain_dassonville', 'Sylvain DASSONVILLE'),
('chef_djamel_mokraoui', 'Djamel MOKRAOUI'),
('chef_jordan_delrue', 'Jordan DELRUE'),
('chef_hamid_urrich', 'Hamid URRICH'),
('chef_samuel_delepierre', 'Samuel DELEPIERRE'),
('chef_antoine_mortier', 'Antoine MORTIER'),
('chef_william_vandekerckhove', 'William VANDEKERCKHOVE'),
('chef_reynald_schroeyers', 'Reynald SCHROEYERS'),
('chef_kamal_abdellaoui', 'Kamal ABDELLAOUI'),
('chef_abdoulaye_bah', 'Abdoulaye BAH'),
('chef_mohamed_oukas', 'Mohamed OUKAS'),
('chef_azzedine_rarbi', 'Azzedine RARBI')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO teams(id, name, chef_id)
VALUES
('team_gestionnaire_de_paie', 'Équipe Gestionnaire de paie', 'chef_gestionnaire_de_paie'),
('team_philippe_grember', 'Équipe Philippe GREMBER', 'chef_philippe_grember'),
('team_elodie_delesalle', 'Équipe Elodie DELESALLE', 'chef_elodie_delesalle'),
('team_georges_d_haene', 'Équipe Georges D''HAENE', 'chef_georges_d_haene'),
('team_pierre_alexandre_huyghe', 'Équipe Pierre Alexandre HUYGHE', 'chef_pierre_alexandre_huyghe'),
('team_adelaide_gros', 'Équipe Adélaïde GROS', 'chef_adelaide_gros'),
('team_sylvain_dassonville', 'Équipe Sylvain DASSONVILLE', 'chef_sylvain_dassonville'),
('team_djamel_mokraoui', 'Équipe Djamel MOKRAOUI', 'chef_djamel_mokraoui'),
('team_jordan_delrue', 'Équipe Jordan DELRUE', 'chef_jordan_delrue'),
('team_hamid_urrich', 'Équipe Hamid URRICH', 'chef_hamid_urrich'),
('team_samuel_delepierre', 'Équipe Samuel DELEPIERRE', 'chef_samuel_delepierre'),
('team_antoine_mortier', 'Équipe Antoine MORTIER', 'chef_antoine_mortier'),
('team_william_vandekerckhove', 'Équipe William VANDEKERCKHOVE', 'chef_william_vandekerckhove'),
('team_reynald_schroeyers', 'Équipe Reynald SCHROEYERS', 'chef_reynald_schroeyers'),
('team_kamal_abdellaoui', 'Équipe Kamal ABDELLAOUI', 'chef_kamal_abdellaoui'),
('team_abdoulaye_bah', 'Équipe Abdoulaye BAH', 'chef_abdoulaye_bah'),
('team_mohamed_oukas', 'Équipe Mohamed OUKAS', 'chef_mohamed_oukas'),
('team_azzedine_rarbi', 'Équipe Azzedine RARBI', 'chef_azzedine_rarbi')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, chef_id = EXCLUDED.chef_id;

INSERT INTO teams(id, name, chef_id)
VALUES ('UNASSIGNED', 'Non affectés', NULL)
ON CONFLICT (id) DO NOTHING;

COMMIT;
