<%@ Page Language="C#" AutoEventWireup="true" CodeFile="NewOrder.aspx.cs" Inherits="Orders_NewOrder" %>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>New Order - Northwind Logistics</title>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
    <link rel="stylesheet" href="/styles/main.css" />
    <style>
        body { font-family: Arial, sans-serif; font-size: 12px; margin: 0; background: #f0f0f0; }
        .header { background: #003366; color: white; padding: 8px 16px; }
        .header h1 { margin: 0; font-size: 18px; }
        .nav { background: #336699; padding: 4px 16px; }
        .nav a { color: white; text-decoration: none; margin-right: 16px; font-size: 12px; }
        .form-section { background: white; border: 1px solid #ccc; padding: 16px; margin: 16px; }
        .form-section h3 { margin: 0 0 12px 0; color: #003366; border-bottom: 1px solid #eee; padding-bottom: 6px; }
        label { display: inline-block; width: 160px; font-weight: bold; }
        input[type=text], select, textarea { width: 280px; border: 1px solid #999; padding: 3px; font-size: 12px; }
        .required { color: red; }
        .field-row { margin-bottom: 8px; }
        .btn-submit { background: #003366; color: white; padding: 8px 24px; border: none; cursor: pointer; font-size: 13px; }
        .error { color: red; font-weight: bold; padding: 8px; background: #ffe0e0; border: 1px solid red; margin: 8px 16px; }
        .success { color: green; font-weight: bold; padding: 8px; background: #e0ffe0; border: 1px solid green; margin: 8px 16px; }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <div class="header"><h1>Northwind Logistics &mdash; New Order</h1></div>
        <div class="nav">
            <a href="/Default.aspx">Dashboard</a>
            <a href="OrderList.aspx">Orders</a>
            <a href="NewOrder.aspx">New Order</a>
            <a href="/Customers/CustomerList.aspx">Customers</a>
        </div>

        <asp:Label ID="lblError"   runat="server" CssClass="error"   Visible="false" />
        <asp:Label ID="lblSuccess" runat="server" CssClass="success" Visible="false" />

        <!-- Customer -->
        <div class="form-section">
            <h3>Customer</h3>
            <div class="field-row">
                <label>Customer <span class="required">*</span></label>
                <asp:DropDownList ID="ddlCustomer" runat="server" Width="284px" />
                &nbsp;<a href="/Customers/CustomerList.aspx" target="_blank" style="font-size:11px;">New customer</a>
            </div>
        </div>

        <!-- Pickup -->
        <div class="form-section">
            <h3>Pickup Location</h3>
            <div class="field-row">
                <label>Address <span class="required">*</span></label>
                <asp:TextBox ID="txtPickupAddress" runat="server" />
            </div>
            <div class="field-row">
                <label>City <span class="required">*</span></label>
                <asp:TextBox ID="txtPickupCity" runat="server" />
            </div>
            <div class="field-row">
                <label>State</label>
                <asp:TextBox ID="txtPickupState" runat="server" MaxLength="2" Width="40px" />
            </div>
            <div class="field-row">
                <label>ZIP</label>
                <asp:TextBox ID="txtPickupZip" runat="server" MaxLength="10" Width="80px" />
            </div>
        </div>

        <!-- Delivery -->
        <div class="form-section">
            <h3>Delivery Location</h3>
            <div class="field-row">
                <label>Address <span class="required">*</span></label>
                <asp:TextBox ID="txtDeliveryAddress" runat="server" />
            </div>
            <div class="field-row">
                <label>City <span class="required">*</span></label>
                <asp:TextBox ID="txtDeliveryCity" runat="server" />
            </div>
            <div class="field-row">
                <label>State</label>
                <asp:TextBox ID="txtDeliveryState" runat="server" MaxLength="2" Width="40px" />
            </div>
            <div class="field-row">
                <label>ZIP</label>
                <asp:TextBox ID="txtDeliveryZip" runat="server" MaxLength="10" Width="80px" />
            </div>
        </div>

        <!-- Order Details -->
        <div class="form-section">
            <h3>Order Details</h3>
            <div class="field-row">
                <label>Total Weight (lbs) <span class="required">*</span></label>
                <asp:TextBox ID="txtWeight" runat="server" Width="80px" />
            </div>
            <div class="field-row">
                <label>Est. Miles</label>
                <asp:TextBox ID="txtMiles" runat="server" Width="60px" />
                <span style="font-size:10px; color:#666;"> (leave blank if unknown)</span>
            </div>
            <div class="field-row">
                <label>Required By</label>
                <asp:TextBox ID="txtRequiredDate" runat="server" Width="100px" />
                <span style="font-size:10px; color:#666;"> (MM/DD/YYYY)</span>
            </div>
            <div class="field-row">
                <label>Priority</label>
                <asp:DropDownList ID="ddlPriority" runat="server">
                    <asp:ListItem Value="N" Text="Normal" Selected="True" />
                    <asp:ListItem Value="H" Text="High (+10%)" />
                    <asp:ListItem Value="U" Text="Urgent (+25%)" />
                </asp:DropDownList>
            </div>
            <div class="field-row">
                <label>Hazmat?</label>
                <asp:CheckBox ID="chkHazmat" runat="server" />
                <span style="font-size:10px; color:red;"> (+$75 surcharge)</span>
            </div>
            <div class="field-row">
                <label>Special Instructions</label>
                <asp:TextBox ID="txtInstructions" runat="server" TextMode="MultiLine" Rows="3" />
            </div>
        </div>

        <!-- Items (simplified - full item entry was removed in v3.2 as "rarely used") -->
        <div class="form-section">
            <h3>Item Description <span style="font-size:11px; color:#666;">(optional, for reference)</span></h3>
            <div class="field-row">
                <label>Description</label>
                <asp:TextBox ID="txtItemDesc" runat="server" />
            </div>
            <div class="field-row">
                <label>Quantity</label>
                <asp:TextBox ID="txtItemQty" runat="server" Width="60px" Text="1" />
            </div>
            <!-- Multi-item support was removed. "Nobody used it." - 2016 -->
        </div>

        <div style="margin: 0 16px 16px 16px;">
            <asp:Button ID="btnSubmit" runat="server" Text="Create Order"
                CssClass="btn-submit" OnClick="btnSubmit_Click" />
            &nbsp;
            <asp:Button ID="btnCancel" runat="server" Text="Cancel"
                OnClick="btnCancel_Click" CausesValidation="false"
                style="padding: 8px 16px; cursor: pointer;" />
        </div>
    </form>
</body>
</html>
