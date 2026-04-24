using System;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;
using System.Web.UI.WebControls;

// OrderList.aspx.cs - Order search/list page
// Also handles order detail via ?id= query string (two responsibilities in one page)
// "We'll split it when we have time" - 2013 comment

public partial class Orders_OrderList : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            // If ?id= in query string, show detail view
            string idParam = Request.QueryString["id"];
            if (!string.IsNullOrEmpty(idParam))
            {
                int orderId;
                if (int.TryParse(idParam, out orderId))
                {
                    ShowOrderDetail(orderId);
                    pnlSearch.Visible = false;
                    pnlDetail.Visible = true;
                    return;
                }
            }

            // Default: search view
            pnlSearch.Visible = true;
            pnlDetail.Visible = false;
            PopulateStatusFilter();
            LoadOrders();
        }
    }

    private void PopulateStatusFilter()
    {
        ddlStatus.Items.Add(new ListItem("All", ""));
        ddlStatus.Items.Add(new ListItem("Pending", "Pending"));
        ddlStatus.Items.Add(new ListItem("Assigned", "Assigned"));
        ddlStatus.Items.Add(new ListItem("Picked Up", "PickedUp"));
        ddlStatus.Items.Add(new ListItem("In Transit", "InTransit"));
        ddlStatus.Items.Add(new ListItem("Delivered", "Delivered"));
        ddlStatus.Items.Add(new ListItem("Failed", "Failed"));
        ddlStatus.Items.Add(new ListItem("Cancelled", "Cancelled"));
        ddlStatus.Items.Add(new ListItem("On Hold", "OnHold"));
    }

    private void LoadOrders()
    {
        var cmd = new SqlCommand("usp_SearchOrders");
        cmd.CommandType = CommandType.StoredProcedure;

        // Pass filter values - empty string becomes null
        var status = ddlStatus.SelectedValue;
        cmd.Parameters.AddWithValue("@Status",
            string.IsNullOrEmpty(status) ? DBNull.Value : (object)status);

        var dateFrom = txtDateFrom.Text.Trim();
        cmd.Parameters.AddWithValue("@DateFrom",
            string.IsNullOrEmpty(dateFrom) ? DBNull.Value : (object)DateTime.Parse(dateFrom));

        var dateTo = txtDateTo.Text.Trim();
        cmd.Parameters.AddWithValue("@DateTo",
            string.IsNullOrEmpty(dateTo) ? DBNull.Value : (object)DateTime.Parse(dateTo));

        // @SortBy comes from a hidden field set by column header clicks
        // XSS-safe since it's a postback field, not URL param...
        // Actually it IS a postback field which means the client can set it to anything.
        // injection risk inherited from usp_SearchOrders
        cmd.Parameters.AddWithValue("@SortBy",  hdnSortBy.Value.Length > 0 ? hdnSortBy.Value : "OrderDate");
        cmd.Parameters.AddWithValue("@SortDir", hdnSortDir.Value.Length > 0 ? hdnSortDir.Value : "DESC");

        try
        {
            var dt = DBHelper.ExecuteDataTable(cmd);
            gvOrders.DataSource = dt;
            gvOrders.DataBind();
            lblResultCount.Text = dt.Rows.Count + " orders found";
        }
        catch (Exception ex)
        {
            lblError.Text    = "Search failed: " + ex.Message;
            lblError.Visible = true;
        }
    }

    private void ShowOrderDetail(int orderId)
    {
        var cmd = new SqlCommand("usp_GetOrder");
        cmd.CommandType = CommandType.StoredProcedure;
        cmd.Parameters.AddWithValue("@OrderID", orderId);

        try
        {
            var ds = DBHelper.ExecuteDataSet(cmd);
            if (ds.Tables.Count < 1 || ds.Tables[0].Rows.Count == 0)
            {
                lblError.Text = "Order not found: " + orderId;
                lblError.Visible = true;
                return;
            }

            // Result set 1: order header
            var order = ds.Tables[0].Rows[0];
            lblOrderID.Text     = order["OrderID"].ToString();
            lblOrderDate.Text   = Convert.ToDateTime(order["OrderDate"]).ToString("MM/dd/yyyy HH:mm");
            lblCustomer.Text    = order["CompanyName"].ToString();
            lblStatus.Text      = order["Status"].ToString();
            lblCost.Text        = string.Format("{0:C}", order["TotalCost"]);
            lblPickup.Text      = order["PickupAddress"] + ", " + order["PickupCity"];
            lblDelivery.Text    = order["DeliveryAddress"] + ", " + order["DeliveryCity"];
            lblWeight.Text      = order["TotalWeight"].ToString() + " lbs";
            lblInstructions.Text = order["SpecialInstructions"].ToString();

            // Result set 2: items
            if (ds.Tables.Count > 1)
            {
                gvItems.DataSource = ds.Tables[1];
                gvItems.DataBind();
            }

            // Result set 3: shipment
            if (ds.Tables.Count > 2 && ds.Tables[2].Rows.Count > 0)
            {
                var ship = ds.Tables[2].Rows[0];
                lblDriver.Text     = ship["DriverName"].ToString();
                lblDriverPhone.Text = ship["DriverPhone"].ToString();
                lblVehicle.Text    = ship["VehicleDesc"].ToString() + " " + ship["LicensePlate"];
                lblShipStatus.Text = ship["Status"].ToString();
                pnlShipment.Visible = true;
            }

            // Show action buttons based on status
            string currentStatus = order["Status"].ToString();
            btnCancel.Visible   = currentStatus == "Pending" || currentStatus == "Assigned";
            btnFail.Visible     = currentStatus == "InTransit" || currentStatus == "PickedUp";
            btnDeliver.Visible  = currentStatus == "InTransit";
            // Direct delivery from this page added in 2020, bypasses driver confirmation.
            // Dispatch uses it when driver calls in instead of using the (deprecated) mobile app.
            hdnCurrentOrderID.Value = orderId.ToString();
        }
        catch (Exception ex)
        {
            lblError.Text    = "Error loading order: " + ex.Message;
            lblError.Visible = true;
        }
    }

    protected void btnSearch_Click(object sender, EventArgs e)
    {
        LoadOrders();
    }

    protected void btnCancel_Click(object sender, EventArgs e)
    {
        int orderId;
        if (!int.TryParse(hdnCurrentOrderID.Value, out orderId)) return;

        var cmd = new SqlCommand("usp_CancelOrder");
        cmd.CommandType = CommandType.StoredProcedure;
        cmd.Parameters.AddWithValue("@OrderID",     orderId);
        cmd.Parameters.AddWithValue("@Reason",      "Cancelled via web UI");
        cmd.Parameters.AddWithValue("@CancelledBy", Session["Username"] ?? "unknown");

        try
        {
            DBHelper.ExecuteNonQuery(cmd);
            Response.Redirect("OrderList.aspx?id=" + orderId);
        }
        catch (Exception ex)
        {
            lblError.Text = "Cancel failed: " + ex.Message;
            lblError.Visible = true;
        }
    }

    protected void btnDeliver_Click(object sender, EventArgs e)
    {
        int orderId;
        if (!int.TryParse(hdnCurrentOrderID.Value, out orderId)) return;

        var cmd = new SqlCommand("usp_UpdateOrderStatus");
        cmd.CommandType = CommandType.StoredProcedure;
        cmd.Parameters.AddWithValue("@OrderID",   orderId);
        cmd.Parameters.AddWithValue("@NewStatus", "Delivered");
        cmd.Parameters.AddWithValue("@ChangedBy", Session["Username"] ?? "dispatch");
        cmd.Parameters.AddWithValue("@Notes",     "Manually marked delivered via dispatch UI");

        try
        {
            DBHelper.ExecuteNonQuery(cmd);
            Response.Redirect("OrderList.aspx?id=" + orderId);
        }
        catch (Exception ex)
        {
            lblError.Text = "Status update failed: " + ex.Message;
            lblError.Visible = true;
        }
    }

    protected void btnFail_Click(object sender, EventArgs e)
    {
        int orderId;
        if (!int.TryParse(hdnCurrentOrderID.Value, out orderId)) return;

        // Get shipment ID for this order
        int shipmentId = -1;
        using (var conn = DBHelper.GetConnection())
        {
            conn.Open();
            using (var cmd = new SqlCommand(
                "SELECT TOP 1 ShipmentID FROM Shipments WHERE OrderID=@OID " +
                "AND Status IN ('PickedUp','InTransit') ORDER BY ShipmentID DESC", conn))
            {
                cmd.Parameters.AddWithValue("@OID", orderId);
                var val = cmd.ExecuteScalar();
                if (val != null) shipmentId = (int)val;
            }
        }

        if (shipmentId < 0)
        {
            lblError.Text = "No active shipment found for this order.";
            lblError.Visible = true;
            return;
        }

        var failCmd = new SqlCommand("usp_FailShipment");
        failCmd.CommandType = CommandType.StoredProcedure;
        failCmd.Parameters.AddWithValue("@ShipmentID",   shipmentId);
        failCmd.Parameters.AddWithValue("@FailureReason","Failed - reported by dispatch");
        failCmd.Parameters.AddWithValue("@ReportedBy",   Session["Username"] ?? "dispatch");

        try
        {
            DBHelper.ExecuteNonQuery(failCmd);
            Response.Redirect("OrderList.aspx?id=" + orderId);
        }
        catch (Exception ex)
        {
            lblError.Text = "Fail update failed: " + ex.Message;
            lblError.Visible = true;
        }
    }
}
