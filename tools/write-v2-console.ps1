param([string]$Root="C:\amp-one")
$ErrorActionPreference = "Stop"

function Ensure-Dir($p){ if(-not (Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

$consoleDir = Join-Path $Root "apps\console"
Ensure-Dir $consoleDir

# ---------- index.html (V2 + sous-onglet "Site") ----------
$index = @'
<!doctype html>
<html lang="fr">
  <head>
    <meta charset="utf-8" />
    <title>AMP One Console — V2 (Site tab)</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      :root { --bg:#0b0b0f; --panel:#141420; --line:#26263a; --text:#eaeaf2; --muted:#aab; --accent:#3b82f6; }
      html,body{margin:0;padding:0;background:var(--bg);color:var(--text);font-family:system-ui,Segoe UI,Roboto,Arial}
      .wrap{max-width:1100px;margin:0 auto;padding:18px}
      .top{display:flex;align-items:center;justify-content:space-between;padding:10px 0}
      .brand{display:flex;align-items:center;gap:10px}
      .badge{background:#1e293b;border:1px solid #334155;border-radius:8px;padding:6px 8px;font-weight:700}
      .title{font-weight:600;opacity:.9}
      .btn{background:#1b1b2b;border:1px solid var(--line);color:var(--text);border-radius:10px;padding:8px 12px;cursor:pointer}
      .btn:hover{background:#1f2432}
      .row{display:flex;gap:8px;align-items:center}
      .sitesbar{display:flex;gap:6px;flex-wrap:wrap;margin:8px 0 16px}
      .sitepill{background:#1b1b2b;border:1px solid var(--line);border-radius:999px;padding:6px 10px;cursor:pointer}
      .sitepill.active{background:var(--accent);color:#fff;border-color:var(--accent)}
      .tabs{display:flex;gap:6px;flex-wrap:wrap;margin:0 0 12px}
      .tab{background:#1b1b2b;border:1px solid var(--line);border-radius:8px;padding:6px 10px;cursor:pointer}
      .tab.active{background:#334155;border-color:#334155}
      .card{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:16px;margin-bottom:12px}
      .card h3{margin:0 0 8px}
      .muted{color:var(--muted)}
      input,textarea,select{background:#1b1b2b;color:var(--text);border:1px solid #2c2c48;border-radius:8px;padding:8px}
      .grid2{display:grid;grid-template-columns:1fr 1fr;gap:10px}
      a{color:#93c5fd}
      .modal{position:fixed;inset:0;display:none;align-items:center;justify-content:center;background:#0008}
      .modal.open{display:flex}
      .panel{background:var(--panel);border:1px solid var(--line);border-radius:14px;max-width:720px;width:92%;padding:16px}
      .table{width:100%;border-collapse:collapse}
      .table th,.table td{border-bottom:1px solid var(--line);padding:8px;text-align:left}
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="top">
        <div class="brand">
          <div class="badge">AMP</div>
          <div class="title">One Console</div>
        </div>
        <div class="row">
          <button class="btn" id="btnSites">Sites</button>
          <a class="btn" href="http://localhost:8081" target="_blank" rel="noreferrer">Keycloak</a>
          <a class="btn" href="http://localhost:9001" target="_blank" rel="noreferrer">MinIO</a>
        </div>
      </div>

      <div id="sitesbar" class="sitesbar"></div>
      <div id="tabs" class="tabs"></div>
      <div id="content"></div>

      <div class="card">
        <h3>Liens utiles</h3>
        <ul>
          <li>API: <a href="http://localhost:8080/health" target="_blank">/health</a></li>
          <li>Keycloak: <a href="http://localhost:8081" target="_blank">http://localhost:8081</a></li>
          <li>MinIO: <a href="http://localhost:9001" target="_blank">http://localhost:9001</a></li>
        </ul>
      </div>
    </div>

    <!-- Modal gestion des sites -->
    <div id="modal" class="modal">
      <div class="panel">
        <div class="row" style="justify-content:space-between;margin-bottom:8px">
          <h3 style="margin:0">Sites</h3>
          <button class="btn" id="btnCloseModal">Fermer</button>
        </div>
        <div class="row" style="margin-bottom:8px">
          <button class="btn" id="btnAdd">Ajouter</button>
          <button class="btn" id="btnEdit">Modifier</button>
          <button class="btn" id="btnDelete">Supprimer</button>
        </div>
        <table class="table" id="sitesTable">
          <thead><tr><th>#</th><th>Nom</th><th>Adresse</th><th>Code postal</th><th>Ville</th><th>Titulaire</th></tr></thead>
          <tbody></tbody>
        </table>
        <div class="card">
          <div class="grid2">
            <label>Nom<br/><input id="f_name" placeholder="Pharmacie Dupont"/></label>
            <label>Titulaire<br/><input id="f_holder" placeholder="Mme/M. ..."/></label>
            <label>Adresse<br/><input id="f_address" placeholder="12 rue ..."/></label>
            <label>Code postal<br/><input id="f_zip" placeholder="75000"/></label>
            <label>Ville<br/><input id="f_city" placeholder="Paris"/></label>
          </div>
          <div class="row" style="margin-top:10px">
            <button class="btn" id="btnSave">Enregistrer</button>
          </div>
        </div>
      </div>
    </div>

    <script>
      const API = "http://localhost:8080/api/v1";
      // Ajout du sous-onglet "Site" en premier :
      const TABS = ["Site","Importer","APS","Exporter","Monitor","Admin","Pricer Plaza"];

      let state = {
        sites: [],
        currentSiteId: null,
        currentTab: "Site",
        perSite: {}
      };

      function uid(){ return Math.random().toString(36).slice(2,10); }
      function load() {
        try { state.sites = JSON.parse(localStorage.getItem("sites")||"[]"); } catch { state.sites = []; }
        state.currentSiteId = localStorage.getItem("currentSiteId");
        if(!state.currentSiteId && state.sites[0]) state.currentSiteId = state.sites[0].id;
        const savedTab = localStorage.getItem("currentTab");
        state.currentTab = savedTab && TABS.includes(savedTab) ? savedTab : "Site";
        render();
      }
      function save() {
        localStorage.setItem("sites", JSON.stringify(state.sites));
        if(state.currentSiteId) localStorage.setItem("currentSiteId", state.currentSiteId);
        localStorage.setItem("currentTab", state.currentTab);
      }

      function render() {
        const sb = document.getElementById("sitesbar");
        sb.innerHTML = "";
        state.sites.forEach(s => {
          const b = document.createElement("button");
          b.className = "sitepill" + (s.id===state.currentSiteId ? " active": "");
          b.textContent = s.name || "(sans nom)";
          b.onclick = () => { state.currentSiteId = s.id; save(); render(); };
          sb.appendChild(b);
        });
        const tabs = document.getElementById("tabs");
        tabs.innerHTML = "";
        TABS.forEach(t => {
          const b = document.createElement("button");
          b.className = "tab" + (t===state.currentTab ? " active" : "");
          b.textContent = t;
          b.onclick = () => { state.currentTab = t; save(); render(); };
          tabs.appendChild(b);
        });
        renderContent();
        renderSitesTable();
      }

      function currentSite(){ return state.sites.find(s => s.id===state.currentSiteId) || null; }

      function renderContent(){
        const c = document.getElementById("content");
        c.innerHTML = "";
        const site = currentSite();
        if(!site){
          c.innerHTML = '<div class="card"><div class="muted">Aucun site. Ouvrez "Sites" et ajoutez-en un.</div></div>';
          return;
        }
        const header = document.createElement("div");
        header.className = "card";
        header.innerHTML = '<h3>'+site.name+'</h3><div class="muted">'+
          [site.address, (site.zipcode||"")+" "+(site.city||""), site.holder?("Titulaire: "+site.holder):""].filter(Boolean).join(" • ")
          +'</div>';
        c.appendChild(header);

        if(state.currentTab==="Site") c.appendChild(cardSite(site));
        if(state.currentTab==="Importer") c.appendChild(cardImport(site));
        if(state.currentTab==="APS") c.appendChild(cardAPS(site));
        if(state.currentTab==="Exporter") c.appendChild(cardExport(site));
        if(state.currentTab==="Monitor") c.appendChild(cardMonitor(site));
        if(state.currentTab==="Admin") c.appendChild(cardAdmin(site));
        if(state.currentTab==="Pricer Plaza") c.appendChild(cardPlaza(site));
      }

      // -------- Sous-onglets (cartes) --------
      function cardSite(site){
        const wrap = document.createElement("div");
        wrap.className = "card";
        wrap.innerHTML = `
          <h3>Site</h3>
          <div class="grid2">
            <label>Nom<br/><input id="s_name" value="${site.name||""}"/></label>
            <label>Titulaire<br/><input id="s_holder" value="${site.holder||""}"/></label>
            <label>Adresse<br/><input id="s_address" value="${site.address||""}"/></label>
            <label>Code postal<br/><input id="s_zip" value="${site.zipcode||""}"/></label>
            <label>Ville<br/><input id="s_city" value="${site.city||""}"/></label>
          </div>
          <div class="row" style="margin-top:10px">
            <button class="btn" id="s_save">Enregistrer</button>
          </div>
        `;
        wrap.querySelector("#s_save").onclick = () => {
          const s = currentSite(); if(!s) return;
          s.name   = wrap.querySelector("#s_name").value.trim();
          s.holder = wrap.querySelector("#s_holder").value.trim();
          s.address= wrap.querySelector("#s_address").value.trim();
          s.zipcode= wrap.querySelector("#s_zip").value.trim();
          s.city   = wrap.querySelector("#s_city").value.trim();
          save(); render();
        };
        return wrap;
      }

      function cardImport(site){
        const wrap = document.createElement("div");
        wrap.className = "card";
        wrap.innerHTML = '<h3>Importer (CSV)</h3>'+
        '<div class="row"><input type="file" id="csvfile" accept=".csv" />'+
        '<button class="btn" id="btnImport">Importer</button></div>'+
        '<pre id="importOut" class="muted" style="white-space:pre-wrap;margin-top:8px"></pre>';
        wrap.querySelector("#btnImport").onclick = async () => {
          const f = wrap.querySelector("#csvfile").files[0];
          if(!f){ alert("Choisis un CSV"); return; }
          const fd = new FormData(); fd.append("file", f); fd.append("delimiter", ","); fd.append("encoding","utf-8");
          const r = await fetch(API+"/import/csv", { method:"POST", body: fd });
          const j = await r.json();
          wrap.querySelector("#importOut").textContent = JSON.stringify(j, null, 2);
          state.perSite[site.id] ??= {}; state.perSite[site.id].datasetId = j.dataset_id;
        };
        return wrap;
      }

      function cardAPS(site){
        const wrap = document.createElement("div");
        wrap.className = "card";
        wrap.innerHTML = '<h3>APS (mapping)</h3>'+
          '<div><small class="muted">Règles JSON</small></div>'+
          '<textarea id="rules" rows="8" style="width:100%">{\n  "replace_rules":[\n    { "column":"category", "replace":{"OTC":"OTC","RX":"Prescription"} }\n  ],\n  "concat_rules":[\n    { "target":"label", "cols":["brand","name"], "sep":" " }\n  ]\n}</textarea>'+
          '<div class="row" style="margin-top:8px"><button class="btn" id="btnMap">Transformer</button></div>'+
          '<pre id="mapOut" class="muted" style="white-space:pre-wrap;margin-top:8px"></pre>';
        wrap.querySelector("#btnMap").onclick = async () => {
          const ds = state.perSite[site.id]?.datasetId;
          if(!ds){ alert("Importe d’abord un CSV"); return; }
          let rules;
          try { rules = JSON.parse(wrap.querySelector("#rules").value); }
          catch(e){ alert("JSON invalide"); return; }
          const r = await fetch(API+"/aps/map", { method:"POST", headers:{ "Content-Type":"application/json" }, body: JSON.stringify({ dataset_id: ds, ...rules }) });
          const j = await r.json();
          wrap.querySelector("#mapOut").textContent = JSON.stringify(j, null, 2);
          state.perSite[site.id].workId = j.work_id;
        };
        return wrap;
      }

      function cardExport(site){
        const wrap = document.createElement("div");
        wrap.className = "card";
        wrap.innerHTML = '<h3>Exporter (dry-run → MinIO)</h3>'+
          '<div class="row"><button class="btn" id="btnExport">Exporter</button></div>'+
          '<div id="exp" class="muted" style="margin-top:8px"></div>';
        wrap.querySelector("#btnExport").onclick = async () => {
          const wid = state.perSite[site.id]?.workId;
          if(!wid){ alert("Fais d’abord APS"); return; }
          const r = await fetch(API+"/export/dryrun", { method:"POST", headers:{ "Content-Type":"application/json" }, body: JSON.stringify({ work_id: wid }) });
          const j = await r.json();
          wrap.querySelector("#exp").innerHTML = 'Objet S3: <code>'+j.bucket+'/'+j.key+'</code><br/>'+
            (j.presigned_url ? ('<a href="'+j.presigned_url+'" target="_blank" rel="noreferrer">Télécharger (lien éphémère)</a>') : '');
        };
        return wrap;
      }

      function cardMonitor(site){
        const wrap = document.createElement("div");
        wrap.className = "card";
        wrap.innerHTML = '<h3>Monitor</h3><div class="muted">À intégrer: états agents, jobs, journaux...</div>';
        return wrap;
      }
      function cardAdmin(site){
        const wrap = document.createElement("div");
        wrap.className = "card";
        wrap.innerHTML = '<h3>Admin</h3><div class="muted">À intégrer: gestion accès, pages cachées, etc.</div>';
        return wrap;
      }
      function cardPlaza(site){
        const wrap = document.createElement("div");
        wrap.className = "card";
        wrap.innerHTML = '<h3>Pricer Plaza</h3><div class="muted">Intégration iFrame (future) — nécessite auth tiers.</div>';
        return wrap;
      }

      // -------- Modal Sites --------
      const modal = document.getElementById("modal");
      document.getElementById("btnSites").onclick = () => { modal.classList.add("open"); renderSitesTable(); };
      document.getElementById("btnCloseModal").onclick = () => { modal.classList.remove("open"); };

      function renderSitesTable(){
        const tb = document.querySelector("#sitesTable tbody");
        tb.innerHTML = "";
        state.sites.forEach((s, i) => {
          const tr = document.createElement("tr");
          tr.innerHTML = '<td>'+ (i+1) +'</td><td>'+ (s.name||"") +'</td><td>'+ (s.address||"") +'</td><td>'+ (s.zipcode||"") +'</td><td>'+ (s.city||"") +'</td><td>'+ (s.holder||"") +'</td>';
          tr.onclick = () => { state.currentSiteId = s.id; save(); render(); };
          tb.appendChild(tr);
        });
        const s = currentSite();
        document.getElementById("f_name").value    = s?.name||"";
        document.getElementById("f_holder").value  = s?.holder||"";
        document.getElementById("f_address").value = s?.address||"";
        document.getElementById("f_zip").value     = s?.zipcode||"";
        document.getElementById("f_city").value    = s?.city||"";
      }

      document.getElementById("btnAdd").onclick = () => {
        const id = uid();
        const s = { id, name: "Nouveau site" };
        state.sites.push(s);
        state.currentSiteId = id;
        save(); renderSitesTable(); render();
      };
      document.getElementById("btnEdit").onclick = () => {
        const s = currentSite(); if(!s){ alert("Sélectionne un site"); return; }
        s.name = document.getElementById("f_name").value.trim();
        s.holder = document.getElementById("f_holder").value.trim();
        s.address = document.getElementById("f_address").value.trim();
        s.zipcode = document.getElementById("f_zip").value.trim();
        s.city = document.getElementById("f_city").value.trim();
        save(); renderSitesTable(); render();
      };
      document.getElementById("btnDelete").onclick = () => {
        const s = currentSite(); if(!s){ alert("Sélectionne un site"); return; }
        if(!confirm("Supprimer "+s.name+" ?")) return;
        state.sites = state.sites.filter(x => x.id !== s.id);
        if(state.sites.length){ state.currentSiteId = state.sites[0].id; } else { state.currentSiteId = null; }
        save(); renderSitesTable(); render();
      };

      // Bouton "Enregistrer" (dans la carte modal)
      document.getElementById("btnSave").onclick = () => {
        const s = currentSite(); if(!s){ alert("Sélectionne un site"); return; }
        s.name = document.getElementById("f_name").value.trim();
        s.holder = document.getElementById("f_holder").value.trim();
        s.address = document.getElementById("f_address").value.trim();
        s.zipcode = document.getElementById("f_zip").value.trim();
        s.city = document.getElementById("f_city").value.trim();
        save(); renderSitesTable(); render();
      };

      load();
    </script>
  </body>
</html>
'@

Set-Content -Path (Join-Path $consoleDir "index.html") -Value $index -Encoding UTF8

# ---------- Dockerfile simple pour la console ----------
$df = @'
FROM nginx:1.27-alpine
COPY index.html /usr/share/nginx/html/index.html
'@
Set-Content -Path (Join-Path $consoleDir "Dockerfile") -Value $df -Encoding ASCII

# ---------- Build + run uniquement la console ----------
Push-Location (Join-Path $Root "infra")
docker compose build console
docker compose up -d console
Pop-Location

Write-Host "OK. Console V2 avec sous-onglet 'Site' dispo: http://localhost:5173" -ForegroundColor Green
