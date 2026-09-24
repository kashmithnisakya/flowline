"""Sample data for the hero demo: a four-step flow line and six tasks, each
with its travel so far, newest first, in the words the server logs."""

glob:pub ROUTE: list[dict[str, str]] = [
         {"name": "Specify", "kind": "start", "color": "sky"},
         {"name": "Build", "kind": "active", "color": "indigo"},
         {"name": "Review", "kind": "handoff", "color": "rose"},
         {"name": "Done", "kind": "done", "color": "emerald"}
     ],
     TASKS: list[dict[str, any]] = [
         {
             "title": "Offline mode for the task list",
             "cat": "Mobile app",
             "due": "",
             "late": False,
             "gh": "",
             "who": ["Amara Perera"],
             "lane": 0,
             "travel": [{"at": "Mon 10:20", "what": "Added to Specify"}]
         },
         {
             "title": "Invoice PDF redesign",
             "cat": "Billing",
             "due": "Due Thu",
             "late": False,
             "gh": "",
             "who": ["Priya Raman"],
             "lane": 1,
             "travel": [
                 {"at": "Tue 09:42", "what": "Moved to Build"},
                 {"at": "Mon 16:05", "what": "Added to Specify"}
             ]
         },
         {
             "title": "Lighthouse score to 95",
             "cat": "Marketing site",
             "due": "1 day overdue",
             "late": True,
             "gh": "",
             "who": ["Leo Martins"],
             "lane": 1,
             "travel": [
                 {"at": "Mon 11:30", "what": "Checked off: Compress hero images (2/4)"},
                 {"at": "Mon 09:10", "what": "Added to Build"}
             ]
         },
         {
             "title": "Webhook for cancelled subscriptions",
             "cat": "Billing",
             "due": "",
             "late": False,
             "gh": "#412",
             "who": ["Priya Raman", "Dev Fernando"],
             "lane": 2,
             "travel": [
                 {"at": "Tue 10:30", "what": "Moved to Review"},
                 {"at": "Mon 14:00", "what": "Moved to Build"}
             ]
         },
         {
             "title": "Stripe SDK upgrade",
             "cat": "Billing",
             "due": "",
             "late": False,
             "gh": "PR #405",
             "who": ["Priya Raman"],
             "lane": 3,
             "travel": [{"at": "Mon 17:20", "what": "Moved to Done · PR merged"}]
         },
         {
             "title": "Receipt emails missing VAT number",
             "cat": "Billing",
             "due": "",
             "late": False,
             "gh": "#398",
             "who": [],
             "lane": 3,
             "travel": [{"at": "Tue 09:15", "what": "Moved to Done · issue closed"}]
         }
     ];
