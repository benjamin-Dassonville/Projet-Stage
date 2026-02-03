import express from "express";
import { pool } from "../db.js";

const router = express.Router();

/**
 * GET /check-audits/:checkId
 * Historique complet
 */
router.get("/:checkId", async (req, res, next) => {
  try {
    const { checkId } = req.params;

    const { rows } = await pool.query(
      `
      select revision, action, changed_by, changed_at, snapshot
      from check_audits
      where check_id = $1
      order by revision asc
      `,
      [checkId]
    );

    res.json(rows);
  } catch (e) {
    next(e);
  }
});

/**
 * GET /check-audits/:checkId/diff
 * Renvoie original (première revision) vs modified (dernière revision)
 */
router.get("/:checkId/diff", async (req, res, next) => {
  try {
    const { checkId } = req.params;

    const { rows } = await pool.query(
      `
      select revision, action, snapshot
      from check_audits
      where check_id = $1
      order by revision asc
      `,
      [checkId]
    );

    if (rows.length < 2) {
      return res.json({ hasUpdate: false });
    }

    const original = rows[0]?.snapshot ?? null;
    const modified = rows[rows.length - 1]?.snapshot ?? null;

    // s'il n'y a jamais eu d'update, on ne montre rien
    const hasUpdate = rows.some(r => r.action === 'UPDATE');

    if (!hasUpdate || !original || !modified) {
      return res.json({ hasUpdate: false });
    }

    return res.json({
      hasUpdate: true,
      original,
      modified,
    });
  } catch (e) {
    next(e);
  }
});

/**
 * GET /check-audits/:checkId/baseline
 * Renvoie la baseline (original) et la version courante, plus les items changés
 */
router.get("/:checkId/baseline", async (req, res, next) => {
  try {
    const { checkId } = req.params;

    // Original = plus petite revision
    const origQ = await pool.query(
      `
      select revision, action, changed_by, changed_at, snapshot
      from check_audits
      where check_id = $1
      order by revision asc
      limit 1
      `,
      [checkId]
    );

    // Current = plus grande revision
    const curQ = await pool.query(
      `
      select revision, action, changed_by, changed_at, snapshot
      from check_audits
      where check_id = $1
      order by revision desc
      limit 1
      `,
      [checkId]
    );

    if (origQ.rows.length === 0 || curQ.rows.length === 0) {
      return res.status(404).json({ error: "No audits for check" });
    }

    const originalRow = origQ.rows[0];
    const currentRow = curQ.rows[0];

    const hasUpdateQ = await pool.query(
      `
      select exists(
        select 1 from check_audits
        where check_id = $1 and upper(action) = 'UPDATE'
      ) as has_update
      `,
      [checkId]
    );
    const hasUpdate = hasUpdateQ.rows[0].has_update === true;

    const origSnap = originalRow.snapshot || {};
    const curSnap = currentRow.snapshot || {};

    const origCheck = origSnap.check || {};
    const curCheck = curSnap.check || {};

    const origItems = Array.isArray(origSnap.items) ? origSnap.items : [];
    const curItems = Array.isArray(curSnap.items) ? curSnap.items : [];

    // map eqId -> status
    const origByEq = new Map();
    for (const it of origItems) origByEq.set(String(it.equipmentId), String(it.status));

    const curByEq = new Map();
    for (const it of curItems) curByEq.set(String(it.equipmentId), String(it.status));

    const changedItems = [];
    const allEq = new Set([...origByEq.keys(), ...curByEq.keys()]);
    for (const eqId of allEq) {
      const o = origByEq.get(eqId);
      const n = curByEq.get(eqId);
      if (o != null && n != null && o !== n) {
        changedItems.push({ equipmentId: eqId, old: o, new: n });
      }
    }

    return res.json({
      hasUpdate,
      original: {
        revision: originalRow.revision,
        action: originalRow.action,
        changedBy: originalRow.changed_by,
        changedAt: originalRow.changed_at,
        result: origCheck.result ?? null,
        items: origItems,
      },
      current: {
        revision: currentRow.revision,
        action: currentRow.action,
        changedBy: currentRow.changed_by,
        changedAt: currentRow.changed_at,
        result: curCheck.result ?? null,
        items: curItems,
      },
      changedItems,
    });
  } catch (e) {
    next(e);
  }
});

export default router;