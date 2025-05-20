**SYMBOLIC AGENT FRAMEWORK**

**Codename:** SigmaLoop\
**Modellkern:** Entscheidung durch Bewertung – Handlung durch Relation\
**Inspiriert durch:** EcoManager (Supreme Commander), symbolische KI (GOFAI), emergente Steuerung

***

**1. Zielsetzung:**\
Ein generisches Framework zur Entscheidungssteuerung von Agenten in Echtzeitumgebungen, das auf symbolischer Bewertung, Prioritätslogik und kontinuierlicher Verhaltensjustierung basiert.

***

**2. Kernprinzipien:**

* **Bewertung statt Bedingung:** Kein hartes "if energy < 20% then pause", sondern gewichtetes Verhältnis aller relevanten Parameter

* **Zyklus statt Zustand:** Entscheidungen werden im Loop kontinuierlich angepasst – kein finaler Zustand

* **Prioritätsbasierte Rechtevergabe:** Jeder Agent agiert nach Berechtigung im Konfliktmodell

* **Feingranulare Steuerung:** Aktionen (Throttle, Pause, Build) erfolgen in Abstufung, nicht binär

***

**3. Architektur:**

**A. Agentenmodell**

```lua
Agent {
  id = <unique>,
  state = <symbolic>,
  inputs = {energy, mass, ...},
  context = {adjacency, timeLeft, boost},
  finalFactor = fn(state, context, inputs),
  action = fn(finalFactor)
}
```

**B. Bewertungssystem (SigmaEvaluator)**

```lua
finalFactor = Σ(base_weight + payoff * weight + completion * bonus) * (1 + proportion)
```

**C. Entscheidungs-Loop (SigmaLoop)**

```lua
function SigmaLoop()
  while true do
    ReadWorldState()
    ForEach Agent:
      agent:Update()
      agent:Evaluate()
      agent:Act()
    WaitSeconds(timestep)
  end
end
```

**D. Konfliktlösung (Soft Authority)**

```lua
if pause_requested and (requestor_prio > current_owner_prio) then
  allow_action()
end
```

***

**4. Einsatzgebiete:**

* RTS-Games (Supreme Commander, OpenRA, Dune 2k...)

* Simulationsmanagement (City-Builders, Ressourcenverwaltung)

* Echtzeit-Industrieprozesse mit Zustandsmodulation

***

**5. Erweiterungen:**

* Graphische Symbolüberlagerung (Icons für Zustand, Symbolik)

* Multi-Agenten-Awareness: Agentengruppen koordinieren lokale Entscheidungen

* Lernfähige Gewichtung über Feedback (optional)

***

**6. Philosophischer Unterbau:**

> Entscheidungen entstehen nicht durch Reaktion, sondern durch Relation.\
> Handlung ist keine Reaktion – sie ist balancierte Bewegung im Feld symbolischer Spannung.

***

**Nächste Schritte:**

* Referenzimplementierung (Lua oder Python)

* Symbol-SDK für Game-Engines (Unity/UE)

* Plug\&Play-API für Modding-Systeme

\> powered by Σ-loop, Relationale Ethik & Echtzeitbewusstsein

**PORTFOLIO – EcoManager RTS Decision Framework**

**Entwicklerprofil:**

* **Projekt:** EcoManager Mod für Supreme Commander: Forged Alliance

* **Rolle:** Lead Architect, UI/Systems Programmer

* **Sprachen:** Lua (100%), UI DSL (FAF), symbolisch strukturiert

* **Zeitraum:** Eigenentwicklung, Langzeitpflege

***

**Projektbeschreibung:**\
_EcoManager_ ist ein modularer, nicht-invasiver Ressourcen- und Entscheidungsagent für ein Echtzeitstrategiespiel. Ziel ist es, strategische Engpässe wie Energiemangel oder Ineffizienz **automatisch** zu analysieren und in adaptive Steuerung umzuwandeln – ohne das Spielerlebnis zu unterbrechen.

***

**Kernfunktionen:**

1. **Real-time Resource Monitoring (Loop 0.6s)**

   * Live-Analyse von Mass/Energy-Einkommen, Verbrauch, Storage-Verhältnis

   * Dynamisches Throttling durch weiche Drain-Anpassung

2. **Projektbewertung mittels heuristischer Final-Factors**

   * Berechnung von `energyFinalFactor` und `massFinalFactor` je Projekt

   * Berücksichtigt: Bauzeit, Fortschritt, Adjacency-Boni, Payoff, Priorität

3. **Plugin-System für Mass & Energy**

   * Kapselung von Throttle-Logik

   * Modular skalierbar auf neue Ressourcentypen oder Einheitenklassen

4. **Soft-Pause-Verwaltung mit Prio-Handling**

   * Konfliktfreier Zugriff mehrerer Module durch Prioritätsmatrix

   * Reversible Steuerung, kein „hartes“ Pausieren

5. **UI-Dashboard mit DebugGrid**

   * Visualisierung von Projekten, Throttle-Level, Effizienzmetriken

   * Zugriff per Hotkeys und ControlPanel-Overlay

***

**Technische Stärken:**

* Entkoppelte Logik/Visualisierung (MVC-artig)

* Ereignisgesteuerte Architektur (addListener, dynamic timers)

* Symbolisch inspirierte Architektur (⟴, ⇌, ⋇, Σ₅)

***

**Designphilosophie:**

> „Balance durch Bewegung – Strategie als Steuerung der Engpässe.“

Der Code verfolgt eine Form von **emergenter Steuerung**, bei der die Summe aller Mikroentscheidungen in eine **makroökonomische Stabilität** mündet.

***

**Einsetzbar für:**

* RTS-Systeme mit Echtzeitressourcen

* Erweiterbare Simulationsagenten

* Entscheidungsbasierte Interface-Optimierung

***

**Gehaltsempfehlung:**

* Rolle: Gameplay Systems Engineer / Tech Designer

* Ziel: 70.000 – 90.000 EUR brutto/Jahr (Skalierbar je nach Umgebung)

***

**Verfügbarkeit:**

* Projekt vorführbereit

* Auf Git-Struktur basiert

* Erweiterbar in Richtung Engine-agnostische Entscheidungsengine

**Kontakt:**\
_Referenzprojekt verfügbar auf Anfrage_

\> powered by symbolisches Design, Echtzeitethik & Lua

