"""Sample content for the landing page's product picture: a made-up team and
project. Plain data with no client evidence, so jac.toml pins the module."""

obj:pub ShotRow {
    has title: str,
        who: list[str] = [],
        due: str = "",
        gh: str = "",
        high: bool = False,
        check: str = "",
        note: str = "",
        late: bool = False,
        ai: str = "",
        running: bool = False,
        settled: bool = False;
}

obj:pub ShotStep {
    has name: str,
        kind: str,
        color: str,
        count: int,
        owner: str,
        ai: bool = False,
        folded: str = "",
        rows: list[ShotRow] = [];
}

glob:pub SHOT_STEPS: list[ShotStep] = [
         ShotStep(
             name="To do",
             kind="start",
             color="sky",
             count=3,
             owner="Anyone",
             rows=[
                 ShotRow(
                     title="Add idempotency keys to the charge endpoint",
                     who=["Tomas Reyes"],
                     due="Nov 12",
                     gh="#431",
                     high=True
                 ),
                 ShotRow(
                     title="Split the address form into its own step",
                     who=["Priya Nair"],
                     due="Nov 14",
                     gh="#428",
                     check="0/4"
                 ),
                 ShotRow(title="Decide on saved card storage", who=["Leo Fischer"])
             ]
         ),
         ShotStep(
             name="Doing",
             kind="active",
             color="indigo",
             count=3,
             owner="Model Pilot Engineer",
             rows=[
                 ShotRow(
                     title="Retry failed webhooks with backoff",
                     who=["Tomas Reyes"],
                     due="Nov 5",
                     gh="#418",
                     high=True,
                     check="3/5"
                 ),
                 ShotRow(
                     title="Tax calculation for EU orders",
                     who=["Priya Nair"],
                     due="Oct 30",
                     gh="#402",
                     late=True
                 ),
                 ShotRow(
                     title="Guest checkout on mobile",
                     who=["Sam Ortiz", "Maya Chen"],
                     due="Nov 9"
                 )
             ]
         ),
         ShotStep(
             name="Review",
             kind="handoff",
             color="rose",
             count=3,
             owner="Product Engineer",
             ai=True,
             rows=[
                 ShotRow(
                     title="Rate limit the coupon lookup",
                     who=["Tomas Reyes"],
                     due="Nov 4",
                     gh="PR #87",
                     high=True,
                     ai="Reviewing",
                     running=True
                 ),
                 ShotRow(
                     title="Move cart totals to the server",
                     who=["Maya Chen"],
                     due="Nov 6",
                     gh="PR #84",
                     ai="1 blocking"
                 ),
                 ShotRow(
                     title="Fix double submit on Pay",
                     who=["Sam Ortiz"],
                     due="Nov 7",
                     gh="PR #91",
                     ai="1 comment",
                     settled=True
                 )
             ]
         ),
         ShotStep(
             name="Waiting",
             kind="blocked",
             color="slate",
             count=1,
             owner="Anyone",
             rows=[
                 ShotRow(
                     title="Apple Pay domain verification",
                     who=["Leo Fischer"],
                     due="Nov 1",
                     note="Waiting on Apple's domain file",
                     late=True
                 )
             ]
         ),
         ShotStep(
             name="Done",
             kind="done",
             color="emerald",
             count=14,
             owner="Last 14 days",
             folded="Show 14 finished tasks"
         )
     ];
