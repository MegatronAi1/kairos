# Demo script (about 3 minutes live, 60-second version in brackets)

Setup: laptop browser on the hosted URL (or `docker compose up` locally), phone signed in to the same server, sound on. Replays loop, so alarms keep arriving on their own. To land one exactly when you want it, use **Simulate alarm** in the top bar (or `POST /api/v1/demo/trigger-fault {"reactor_id":"PUN-R1","kind":"oxygen"}`): it replays a real fault batch from 2 h before the fault, and the detector raises the alarm about 5 s later on the web toaster and the phone.

1. **Landing (15 s).** "Every batch has a decisive moment. Kairos finds it." Point at the four KPI cards: real numbers on batches the models never saw.
2. **Sign in (5 s).** Click the operator demo account.
3. **Operations map (20 s).** "Aurora Bioproteins, a fictional company running seven alternative-protein plants across four continents, in cities that host Hack the Fork: Pune, Paris, Lagos, Nairobi, Manila, Providence and Davis." A plant turns red and the alarm toast slides in top right. [Phone buzzes on the table.]
4. **Phone (15 s).** Show the full-screen alarm: "Oxygen transfer dropping", the countdown (about 8 h to the point of no return), the action. Tap Acknowledge; the console shows "Acknowledged".
5. **Plant -> R2 (40 s).** The 3D reactor: oxygen ring and broth colour shifting. Open the dissolved-oxygen tile, then the forecast tile: the yield range widens and drops. Copilot card: cause, one action, expected effect, evidence chips.
6. **Simulate the fix (30 s).** Click "Simulate the fix": fix now keeps about 3,400 kg; wait past the point of no return and it falls; do nothing is about 2,500 and dropping. "Model estimate from healthy analog batches."
7. **Ask Kairos (20 s).** Type "How much energy can PUN-R1 save without risking oxygen?" The answer streams with evidence chips.
8. **Process library (15 s).** Switch to Precision -> Whey protein: stirred-tank schematic, phases, why the benchmark fits Trichoderma fed-batch.
9. **Impact (15 s).** Savings by month, quarter or year: rescued batches, energy, feedstock; export to Excel or PDF. "Plant history is simulated; the improvement rates are our measured results."
10. **Evidence (20 s).** Four KPIs, false alarms 0.2 vs 11.4 for classic MSPC, energy Pareto. "Every number is reproducible from the repo."

Fallbacks: if Bedrock is down, the rule-based card still appears; if venue Wi-Fi fails, run `docker compose up` on the laptop and pair the phone over USB (`adb reverse tcp:8000 tcp:8000`).
