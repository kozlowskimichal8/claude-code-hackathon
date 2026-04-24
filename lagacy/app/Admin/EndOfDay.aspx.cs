using System;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;

// Admin/EndOfDay.aspx.cs
// Manual trigger page for EOD batch. Used when the SQL Agent job fails
// or needs to be re-run for a specific date.
//
// IMPORTANT: This page has NO ROLE CHECK. Any logged-in user can run EOD.
// "Only admins know the URL" - security by obscurity (2012)
// This was discovered during the 2022 security review.
// JIRA ticket NWL-441 created. Status: Open (as of last check).
//
// Also has its own connection string hardcoded (third copy in codebase).

public partial class Admin_EndOfDay : System.Web.UI.Page
{
    // Yet another copy. See web.config and NewOrder.aspx.cs.
    private const string ADMIN_CONN =
        @"Data Source=NWLSQL01;Initial Catalog=NorthwindLogistics;" +
        "User ID=nwl_app;Password=P@ssw0rd2009!;Connect Timeout=600";
    //                                                           ^^^
    //                                  10 minute timeout because EOD is slow

    protected void Page_Load(object sender, EventArgs e)
    {
        // No auth check. See class comment above.
        if (!IsPostBack)
        {
            txtRunDate.Text = DateTime.Today.ToString("MM/dd/yyyy");
        }
    }

    protected void btnRunEOD_Click(object sender, EventArgs e)
    {
        DateTime runDate;
        if (!DateTime.TryParse(txtRunDate.Text.Trim(), out runDate))
        {
            ShowResult("Invalid date format.", false);
            return;
        }

        bool dryRun   = chkDryRun.Checked;
        bool forceRun = chkForceRerun.Checked;

        lblStatus.Text = "Running EOD batch... (this may take several minutes)";
        lblStatus.Visible = true;

        try
        {
            using (var conn = new SqlConnection(ADMIN_CONN))
            {
                conn.Open();
                using (var cmd = new SqlCommand("usp_ProcessEndOfDay", conn))
                {
                    cmd.CommandType    = CommandType.StoredProcedure;
                    cmd.CommandTimeout = 600;  // 10 minutes
                    cmd.Parameters.AddWithValue("@RunDate",    runDate);
                    cmd.Parameters.AddWithValue("@DryRun",     dryRun ? 1 : 0);
                    cmd.Parameters.AddWithValue("@ForceRerun", forceRun ? 1 : 0);

                    using (var rdr = cmd.ExecuteReader())
                    {
                        if (rdr.Read())
                        {
                            int billed  = rdr.IsDBNull(1) ? 0 : rdr.GetInt32(1);
                            int overdue = rdr.IsDBNull(2) ? 0 : rdr.GetInt32(2);
                            int stale   = rdr.IsDBNull(3) ? 0 : rdr.GetInt32(3);
                            int elapsed = rdr.IsDBNull(4) ? 0 : rdr.GetInt32(4);

                            string resultHtml = string.Format(
                                "<strong>EOD {0} complete.</strong><br />" +
                                "Orders auto-billed: {1}<br />" +
                                "Invoices marked overdue: {2}<br />" +
                                "Stale orders found: {3}<br />" +
                                "Elapsed: {4} seconds<br />" +
                                "<em>{5}</em>",
                                dryRun ? "DRY RUN" : "RUN",
                                billed, overdue, stale, elapsed,
                                dryRun ? "No changes were made." : "Changes committed."
                            );
                            ShowResult(resultHtml, true);
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ShowResult("EOD FAILED: " + ex.Message, false);

            // Try to log to AuditLog - open new connection because current one may be in bad state
            try
            {
                using (var logConn = new SqlConnection(ADMIN_CONN))
                {
                    logConn.Open();
                    using (var logCmd = new SqlCommand(
                        "INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy) " +
                        "VALUES ('SYSTEM', 0, 'EOD_ERROR', @msg, @user)", logConn))
                    {
                        logCmd.Parameters.AddWithValue("@msg",  ex.Message);
                        logCmd.Parameters.AddWithValue("@user", Session["Username"] ?? "admin_ui");
                        logCmd.ExecuteNonQuery();
                    }
                }
            }
            catch { /* if logging fails, not much we can do */ }
        }
    }

    protected void btnRunCleanup_Click(object sender, EventArgs e)
    {
        bool dryRun = chkCleanupDryRun.Checked;
        try
        {
            using (var conn = new SqlConnection(ADMIN_CONN))
            {
                conn.Open();
                using (var cmd = new SqlCommand("usp_CleanupTempData", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@DryRun", dryRun ? 1 : 0);

                    var dt = new DataTable();
                    new SqlDataAdapter(cmd).Fill(dt);

                    if (dt.Rows.Count > 0)
                    {
                        var row = dt.Rows[0];
                        ShowResult(string.Format(
                            "Cleanup {0}: Orphaned items={1}, Stuck drivers={2}, Stuck vehicles={3}",
                            dryRun ? "DRY RUN" : "DONE",
                            row["OrphanedOrderItems"],
                            row["StuckDriversFixed"],
                            row["StuckVehiclesFixed"]
                        ), true);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ShowResult("Cleanup failed: " + ex.Message, false);
        }
    }

    protected void btnRebuildIndexes_Click(object sender, EventArgs e)
    {
        // No dry-run for index rebuild. "Either you do it or you don't."
        // This takes 15-20 minutes and locks some tables.
        // No warning to the user. "They should know not to run during business hours."
        ShowResult("Index rebuild started (runs in background)...", true);
        try
        {
            using (var conn = new SqlConnection(ADMIN_CONN))
            {
                conn.Open();
                using (var cmd = new SqlCommand("usp_RebuildIndexes", conn))
                {
                    cmd.CommandType    = CommandType.StoredProcedure;
                    cmd.CommandTimeout = 3600;  // 1 hour - may still timeout
                    cmd.ExecuteNonQuery();
                }
            }
            ShowResult("Index rebuild completed.", true);
        }
        catch (Exception ex)
        {
            ShowResult("Index rebuild failed or timed out: " + ex.Message, false);
        }
    }

    private void ShowResult(string html, bool success)
    {
        lblResult.Text    = html;
        lblResult.Visible = true;
        lblStatus.Visible = false;
        lblResult.ForeColor = success
            ? System.Drawing.Color.DarkGreen
            : System.Drawing.Color.Red;
    }
}
