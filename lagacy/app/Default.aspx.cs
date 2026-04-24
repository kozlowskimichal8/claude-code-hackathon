using System;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;
using System.Web.UI.WebControls;

// Default.aspx.cs - Dashboard page
// R.Kowalski 2009. This file has not been refactored since 2012.
// K.Patel: Added driver/vehicle counts 2014
// T.Wu: Added overdue highlighting 2017
//
// Each data section makes its own DB call. There are 5 separate
// connections opened and closed on every page load.
// "Profile said DB was the bottleneck so we're not caching" - 2018
// (Profile was from 2015, the DB is much faster now)

public partial class Default : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        // No authentication check here. Was supposed to be in Global.asax
        // but that check was commented out "temporarily" in 2021 and never restored.
        // "VPN is the security layer" - ops team

        if (!IsPostBack)
        {
            lblUser.Text = Session["Username"] as string ?? "Unknown";
            LoadDashboard();
        }
    }

    private void LoadDashboard()
    {
        try
        {
            LoadSummaryWidgets();
            LoadPendingOrders();
            LoadActiveShipments();
        }
        catch (Exception ex)
        {
            lblError.Text = "Dashboard load error: " + ex.Message;
            lblError.Visible = true;
            // No logging. Was logged once, log filled up, was disabled.
        }
    }

    private void LoadSummaryWidgets()
    {
        // Today's orders count and revenue - direct SQL, not via stored proc
        // "Faster to write inline SQL for simple queries" - R.Kowalski 2009
        using (var conn = DBHelper.GetConnection())
        {
            conn.Open();

            // Today orders
            using (var cmd = new SqlCommand(
                @"SELECT COUNT(*), ISNULL(SUM(TotalCost), 0)
                  FROM Orders
                  WHERE CAST(OrderDate AS date) = CAST(GETDATE() AS date)", conn))
            {
                using (var rdr = cmd.ExecuteReader())
                {
                    if (rdr.Read())
                    {
                        lblTodayOrders.Text  = rdr[0].ToString();
                        lblTodayRevenue.Text = string.Format("{0:C} est. revenue", rdr[1]);
                    }
                }
            }

            // Active shipments count and overdue
            using (var cmd = new SqlCommand(
                @"SELECT
                    COUNT(*),
                    SUM(CASE WHEN o.RequiredDate < GETDATE() THEN 1 ELSE 0 END)
                  FROM Shipments s
                  INNER JOIN Orders o ON s.OrderID = o.OrderID
                  WHERE s.Status IN ('Assigned','PickedUp','InTransit')", conn))
            {
                using (var rdr = cmd.ExecuteReader())
                {
                    if (rdr.Read())
                    {
                        lblActiveShipments.Text  = rdr[0].ToString();
                        int overdue = rdr.IsDBNull(1) ? 0 : rdr.GetInt32(1);
                        if (overdue > 0)
                            lblOverdueShipments.Text = overdue + " OVERDUE";
                    }
                }
            }

            // Pending orders - calls stored proc
            // But also counts inline because the proc is "too slow for widgets"
            using (var cmd = new SqlCommand(
                "SELECT COUNT(*), SUM(CASE WHEN DATEDIFF(hour,OrderDate,GETDATE())>48 THEN 1 ELSE 0 END) " +
                "FROM Orders WHERE Status='Pending'", conn))
            {
                using (var rdr = cmd.ExecuteReader())
                {
                    if (rdr.Read())
                    {
                        lblPendingOrders.Text = rdr[0].ToString();
                        int stale = rdr.IsDBNull(1) ? 0 : rdr.GetInt32(1);
                        if (stale > 0)
                            lblStalePending.Text = stale + " stale (>48h)";
                    }
                }
            }

            // Drivers and vehicles available
            using (var cmd = new SqlCommand(
                @"SELECT
                    (SELECT COUNT(*) FROM Drivers WHERE Status='Available' AND TerminatedDate IS NULL),
                    (SELECT COUNT(*) FROM Vehicles WHERE Status='Available')", conn))
            {
                using (var rdr = cmd.ExecuteReader())
                {
                    if (rdr.Read())
                    {
                        lblAvailableDrivers.Text  = rdr[0].ToString();
                        lblAvailableVehicles.Text = rdr[1].ToString() + " vehicles available";
                    }
                }
            }
        }
    }

    private void LoadPendingOrders()
    {
        var cmd = new SqlCommand("usp_GetPendingOrders");
        cmd.CommandType = CommandType.StoredProcedure;
        cmd.Parameters.AddWithValue("@HoursOld", 48);

        var dt = DBHelper.ExecuteDataTable(cmd);

        // Highlight overdue rows - done client-side via CSS class in grid template
        gvPendingOrders.DataSource = dt;
        gvPendingOrders.DataBind();
    }

    private void LoadActiveShipments()
    {
        var cmd = new SqlCommand("usp_GetActiveShipments");
        cmd.CommandType = CommandType.StoredProcedure;
        // No @HomeBase filter - shows all locations on dashboard
        // Note: usp_GetActiveShipments uses ##global temp table.
        // If two users hit the dashboard simultaneously this may fail.
        // "Hasn't been an issue" (two people have complained, tickets closed as "can't repro")

        var dt = DBHelper.ExecuteDataTable(cmd);
        gvActiveShipments.DataSource = dt;
        gvActiveShipments.DataBind();
    }

    protected void gvPendingOrders_RowCommand(object sender, GridViewCommandEventArgs e)
    {
        // Placeholder - quick-assign was planned here but not implemented
    }
}
