"""Sample data for the tour's board: five steps with their tasks, each in the
shape DemoLine reads."""

def sample(
    title: str,
    cat: str,
    who: list[str],
    gh: str = "",
    due: str = "",
    late: bool = False
) -> dict[str, any] {
    return {"title": title, "cat": cat, "who": who, "gh": gh, "due": due, "late": late};
}

glob:pub BOARD: list[dict[str, any]] = [
         {
             "name": "Specify",
             "kind": "start",
             "color": "sky",
             "tasks": [
                 sample("Push notification opt-in screen", "Mobile app", ["Nina Park"]),
                 sample("Tax ID field for EU customers", "Billing", ["Ravi Kumar"])
             ]
         },
         {
             "name": "Design",
             "kind": "active",
             "color": "amber",
             "tasks": [
                 sample(
                     "Proration for mid-cycle plan changes", "Billing", ["Dev Fernando"]
                 )
             ]
         },
         {
             "name": "Build",
             "kind": "active",
             "color": "indigo",
             "tasks": [
                 sample(
                     "Invoice PDF redesign", "Billing", ["Priya Raman"], due="Due Thu"
                 ),
                 sample("Dark mode polish on settings", "Mobile app", ["Kasun Silva"])
             ]
         },
         {
             "name": "Review",
             "kind": "handoff",
             "color": "rose",
             "tasks": [
                 sample(
                     "Webhook for cancelled subscriptions",
                     "Billing",
                     ["Priya Raman", "Dev Fernando"],
                     gh="#412"
                 )
             ]
         },
         {
             "name": "Done",
             "kind": "done",
             "color": "emerald",
             "tasks": [sample("Stripe SDK upgrade", "Billing", ["Priya Raman"])]
         }
     ];
