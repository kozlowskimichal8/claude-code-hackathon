using System;
using System.Data;
using System.Data.SqlClient;
using System.Configuration;

// NewOrder.aspx.cs
// R.Kowalski 2009. Last significant change: T.Wu 2017 (added hazmat checkbox).
//
// WARNING: This page has its OWN connection string - copied from web.config
// in 2012 because "the DBHelper wasn't working right that day".
// Never cleaned up. If the password changes, change it here too.
// See also: Admin/EndOfDay.aspx.cs which has yet ANOTHER copy.

public partial class Orders_NewOrder : System.Web.UI.Page
{
    // Third copy of the connection string in this codebase
    private const string CONN = @"Data Source=NWLSQL01;Initial Catalog=NorthwindLogistics;" +
                                  "User ID=nwl_app;Password=P@ssw0rd2009!;Connect Timeout=30";

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            LoadCustomers();
        }
    }

    private void LoadCustomers()
    {
        using (var conn = new SqlConnection(CONN))  // uses hardcoded string
        {
            conn.Open();
            // Inline SQL, not via stored proc
            using (var cmd = new SqlCommand(
                "SELECT CustomerID, CompanyName + ' (' + CustomerType + ')' AS Display " +
                "FROM Customers WHERE IsActive=1 ORDER BY CompanyName", conn))
            {
                var dt = new DataTable();
                new SqlDataAdapter(cmd).Fill(dt);
                ddlCustomer.DataSource     = dt;
                ddlCustomer.DataTextField  = "Display";
                ddlCustomer.DataValueField = "CustomerID";
                ddlCustomer.DataBind();
                ddlCustomer.Items.Insert(0, new System.Web.UI.WebControls.ListItem("-- Select Customer --", "0"));
            }
        }
    }

    protected void btnSubmit_Click(object sender, EventArgs e)
    {
        // Validation - minimal, done in code-behind
        if (ddlCustomer.SelectedValue == "0")
        {
            ShowError("Please select a customer.");
            return;
        }
        if (string.IsNullOrEmpty(txtPickupAddress.Text.Trim()))
        {
            ShowError("Pickup address is required.");
            return;
        }
        if (string.IsNullOrEmpty(txtDeliveryAddress.Text.Trim()))
        {
            ShowError("Delivery address is required.");
            return;
        }

        decimal weight = 0;
        if (!decimal.TryParse(txtWeight.Text.Trim(), out weight) || weight <= 0)
        {
            ShowError("Please enter a valid weight.");
            return;
        }

        int? miles = null;
        if (!string.IsNullOrEmpty(txtMiles.Text.Trim()))
        {
            int m;
            if (!int.TryParse(txtMiles.Text.Trim(), out m))
            {
                ShowError("Estimated miles must be a whole number.");
                return;
            }
            miles = m;
        }

        DateTime? requiredDate = null;
        if (!string.IsNullOrEmpty(txtRequiredDate.Text.Trim()))
        {
            DateTime rd;
            if (!DateTime.TryParse(txtRequiredDate.Text.Trim(), out rd))
            {
                ShowError("Invalid required date format. Use MM/DD/YYYY.");
                return;
            }
            requiredDate = rd;
        }

        // Create order via stored proc
        int newOrderID = -1;
        try
        {
            using (var conn = new SqlConnection(CONN))
            {
                conn.Open();
                using (var cmd = new SqlCommand("usp_CreateOrder", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@CustomerID",      int.Parse(ddlCustomer.SelectedValue));
                    cmd.Parameters.AddWithValue("@PickupAddress",   txtPickupAddress.Text.Trim());
                    cmd.Parameters.AddWithValue("@PickupCity",      txtPickupCity.Text.Trim());
                    cmd.Parameters.AddWithValue("@PickupState",     txtPickupState.Text.Trim().ToUpper());
                    cmd.Parameters.AddWithValue("@PickupZip",       txtPickupZip.Text.Trim());
                    cmd.Parameters.AddWithValue("@DeliveryAddress", txtDeliveryAddress.Text.Trim());
                    cmd.Parameters.AddWithValue("@DeliveryCity",    txtDeliveryCity.Text.Trim());
                    cmd.Parameters.AddWithValue("@DeliveryState",   txtDeliveryState.Text.Trim().ToUpper());
                    cmd.Parameters.AddWithValue("@DeliveryZip",     txtDeliveryZip.Text.Trim());
                    cmd.Parameters.AddWithValue("@TotalWeight",     weight);
                    cmd.Parameters.AddWithValue("@Priority",        ddlPriority.SelectedValue);
                    cmd.Parameters.AddWithValue("@IsHazmat",        chkHazmat.Checked ? 1 : 0);
                    cmd.Parameters.AddWithValue("@SpecialInstructions",
                        string.IsNullOrEmpty(txtInstructions.Text) ? DBNull.Value : (object)txtInstructions.Text.Trim());
                    cmd.Parameters.AddWithValue("@CreatedBy",       Session["Username"] ?? "unknown");

                    // Optional params
                    if (requiredDate.HasValue)
                        cmd.Parameters.AddWithValue("@RequiredDate", requiredDate.Value);
                    if (miles.HasValue)
                        cmd.Parameters.AddWithValue("@EstimatedMiles", miles.Value);

                    // OUTPUT parameter - note: this doesn't use DBHelper.ExecuteWithOutput
                    // because that only supports "@NewID" but this proc uses "@NewOrderID"
                    // Another inconsistency from 2012.
                    var outParam = cmd.Parameters.Add("@NewOrderID", SqlDbType.Int);
                    outParam.Direction = ParameterDirection.Output;

                    cmd.ExecuteNonQuery();

                    newOrderID = (int)cmd.Parameters["@NewOrderID"].Value;
                }

                // If item description was provided, add it
                if (!string.IsNullOrEmpty(txtItemDesc.Text.Trim()) && newOrderID > 0)
                {
                    int qty = 1;
                    int.TryParse(txtItemQty.Text.Trim(), out qty);

                    using (var cmd2 = new SqlCommand(
                        "INSERT INTO OrderItems (OrderID, Description, Quantity, WeightLbs) " +
                        "VALUES (@OID, @Desc, @Qty, @Wt)", conn))
                    {
                        cmd2.Parameters.AddWithValue("@OID",  newOrderID);
                        cmd2.Parameters.AddWithValue("@Desc", txtItemDesc.Text.Trim());
                        cmd2.Parameters.AddWithValue("@Qty",  qty);
                        cmd2.Parameters.AddWithValue("@Wt",   weight); // assumes single item = total weight
                        cmd2.ExecuteNonQuery();
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ShowError("Order creation failed: " + ex.Message);
            // Log to AuditLog? No - too much trouble to open another connection here.
            return;
        }

        if (newOrderID > 0)
        {
            lblSuccess.Text    = string.Format("Order #{0} created successfully. ", newOrderID) +
                                 "<a href='OrderList.aspx?id=" + newOrderID + "'>View order</a>";
            lblSuccess.Visible = true;
            ClearForm();
        }
        else
        {
            ShowError("Order creation returned an error. Check the database.");
        }
    }

    protected void btnCancel_Click(object sender, EventArgs e)
    {
        Response.Redirect("~/Default.aspx");
    }

    private void ShowError(string message)
    {
        lblError.Text    = message;
        lblError.Visible = true;
        lblSuccess.Visible = false;
    }

    private void ClearForm()
    {
        txtPickupAddress.Text = txtPickupCity.Text = txtPickupState.Text = txtPickupZip.Text = "";
        txtDeliveryAddress.Text = txtDeliveryCity.Text = txtDeliveryState.Text = txtDeliveryZip.Text = "";
        txtWeight.Text = txtMiles.Text = txtRequiredDate.Text = txtInstructions.Text = "";
        txtItemDesc.Text = ""; txtItemQty.Text = "1";
        ddlPriority.SelectedValue = "N";
        chkHazmat.Checked = false;
    }
}
