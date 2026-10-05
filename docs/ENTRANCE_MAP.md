# Farm entrances

Segment 21f gives each service a home. The entrance assertions in `test_ui_audit.gd` check this map across the actual HUD buttons and world targets.

| Thing to do | Entrance | Allowed shortcut |
| --- | --- | --- |
| Sell, store, keep crop seed, or accept a buyer order | Barn | HUD Sell opens the same barn page; annual accounts have one “Go to the barn” link |
| Buy seeds | Mara's stall | None |
| Accounts, bills, leases and Winter business plans | Nell | None; accounts are readable in any season, leases remain Winter decisions |
| Weather, insurance and protection | Weather station | Weather pill opens the same page |
| Quests and loss records | Tess's board | None |
| Tool upgrades, Home expansion, barn extension and cosmetic decorations | Tools shed | None |

The Menu inventory lists potatoes by grade and seeds. It cannot sell anything and has no Tools tab. The tray equips tools. Winter stores are facts, with no selling or seed-page entrance; use Sell or walk to the barn. The menu does not duplicate the farm's services. The old shop Sell tab, direct quick sell, separate stores/loss/business pages, buyer-board entrance and service keyboard shortcuts are removed. F is the keyboard equivalent of the HUD Sell shortcut and opens the barn.

Every mapped entrance first opens its keeper’s short seasonal greeting, with one button for that same service. This includes HUD Sell, Weather, Nell, Tess and ducks. Close leaves the greeting without opening a shop. “Talk” on a service page keeps personal stories available. This follows the owner’s later request to restore interaction before all services, overriding Segment 21f H’s service-first instruction. Each service has one Close button. The camera, movement and tool keys remain controls, not extra pages.
