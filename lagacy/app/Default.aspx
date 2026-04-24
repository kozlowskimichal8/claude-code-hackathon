<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="Default" %>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Northwind Logistics - Operations</title>
    <!-- jQuery 1.9.1 - yes, from 2013. Upgrading breaks the date picker. -->
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
    <link rel="stylesheet" href="/styles/main.css" />
    <style>
        body { font-family: Arial, sans-serif; font-size: 12px; margin: 0; background: #f0f0f0; }
        .header { background: #003366; color: white; padding: 8px 16px; }
        .header h1 { margin: 0; font-size: 18px; }
        .nav { background: #336699; padding: 4px 16px; }
        .nav a { color: white; text-decoration: none; margin-right: 16px; font-size: 12px; }
        .nav a:hover { text-decoration: underline; }
        .content { padding: 16px; }
        .widget { background: white; border: 1px solid #ccc; padding: 12px; margin-bottom: 12px; float: left; width: 22%; margin-right: 2%; }
        .widget h3 { margin: 0 0 8px 0; font-size: 14px; color: #003366; border-bottom: 1px solid #ccc; padding-bottom: 4px; }
        .big-number { font-size: 32px; font-weight: bold; color: #003366; }
        .alert { color: red; font-weight: bold; }
        .clearfix { clear: both; }
        table.grid { width: 100%; border-collapse: collapse; background: white; }
        table.grid th { background: #336699; color: white; padding: 4px 8px; text-align: left; font-size: 11px; }
        table.grid td { padding: 4px 8px; border-bottom: 1px solid #eee; font-size: 11px; }
        table.grid tr:hover td { background: #f0f8ff; }
        .status-Pending   { color: orange; font-weight: bold; }
        .status-Delivered { color: green; }
        .status-Failed    { color: red; font-weight: bold; }
        .status-InTransit { color: #0066cc; }
        .status-Cancelled { color: gray; }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <div class="header">
            <h1>Northwind Logistics &mdash; Operations Dashboard</h1>
            <span style="font-size: 11px;">
                Logged in as: <strong><asp:Label ID="lblUser" runat="server" /></strong>
                &nbsp;|&nbsp; <a href="Login.aspx?action=logout" style="color:#aaa;">Logout</a>
                &nbsp;|&nbsp; <span id="clock"></span>
            </span>
        </div>
        <div class="nav">
            <a href="Default.aspx">Dashboard</a>
            <a href="Orders/OrderList.aspx">Orders</a>
            <a href="Orders/NewOrder.aspx">New Order</a>
            <a href="Shipments/ShipmentTracking.aspx">Tracking</a>
            <a href="Customers/CustomerList.aspx">Customers</a>
            <a href="Admin/EndOfDay.aspx">Admin</a>
        </div>
        <div class="content">

            <asp:Label ID="lblError" runat="server" ForeColor="Red" Visible="false" />

            <!-- Summary Widgets -->
            <div class="widget">
                <h3>Today's Orders</h3>
                <div class="big-number"><asp:Label ID="lblTodayOrders" runat="server">0</asp:Label></div>
                <div><asp:Label ID="lblTodayRevenue" runat="server" /></div>
            </div>
            <div class="widget">
                <h3>Active Shipments</h3>
                <div class="big-number"><asp:Label ID="lblActiveShipments" runat="server">0</asp:Label></div>
                <div class="alert"><asp:Label ID="lblOverdueShipments" runat="server" /></div>
            </div>
            <div class="widget">
                <h3>Pending Orders</h3>
                <div class="big-number"><asp:Label ID="lblPendingOrders" runat="server">0</asp:Label></div>
                <div class="alert"><asp:Label ID="lblStalePending" runat="server" /></div>
            </div>
            <div class="widget">
                <h3>Available Drivers</h3>
                <div class="big-number"><asp:Label ID="lblAvailableDrivers" runat="server">0</asp:Label></div>
                <div><asp:Label ID="lblAvailableVehicles" runat="server" /></div>
            </div>
            <div class="clearfix"></div>

            <!-- Recent Pending Orders -->
            <h3 style="margin-top: 16px;">Pending Orders Awaiting Assignment</h3>
            <asp:GridView ID="gvPendingOrders" runat="server"
                AutoGenerateColumns="False"
                CssClass="grid"
                EmptyDataText="No pending orders."
                OnRowCommand="gvPendingOrders_RowCommand">
                <Columns>
                    <asp:BoundField DataField="OrderID"     HeaderText="Order #" />
                    <asp:BoundField DataField="OrderDate"   HeaderText="Received"       DataFormatString="{0:MM/dd/yyyy HH:mm}" />
                    <asp:BoundField DataField="CompanyName" HeaderText="Customer" />
                    <asp:BoundField DataField="PickupCity"  HeaderText="Pickup" />
                    <asp:BoundField DataField="DeliveryCity" HeaderText="Deliver To" />
                    <asp:BoundField DataField="TotalWeight" HeaderText="Weight (lbs)"   DataFormatString="{0:N1}" />
                    <asp:BoundField DataField="TotalCost"   HeaderText="Est. Cost"      DataFormatString="{0:C}" />
                    <asp:BoundField DataField="Priority"    HeaderText="Pri" />
                    <asp:BoundField DataField="HoursPending" HeaderText="Hrs Pending" />
                    <asp:TemplateField HeaderText="">
                        <ItemTemplate>
                            <a href='Orders/OrderList.aspx?id=<%# Eval("OrderID") %>'>View</a>
                        </ItemTemplate>
                    </asp:TemplateField>
                </Columns>
            </asp:GridView>

            <!-- Active Shipments -->
            <h3 style="margin-top: 16px;">Active Shipments</h3>
            <asp:GridView ID="gvActiveShipments" runat="server"
                AutoGenerateColumns="False"
                CssClass="grid"
                EmptyDataText="No active shipments.">
                <Columns>
                    <asp:BoundField DataField="ShipmentID"  HeaderText="Shipment #" />
                    <asp:BoundField DataField="OrderID"     HeaderText="Order #" />
                    <asp:BoundField DataField="CustomerName" HeaderText="Customer" />
                    <asp:BoundField DataField="DriverName"  HeaderText="Driver" />
                    <asp:BoundField DataField="Status"      HeaderText="Status" />
                    <asp:BoundField DataField="PickupLocation"   HeaderText="Pickup" />
                    <asp:BoundField DataField="DeliveryLocation" HeaderText="Delivering To" />
                    <asp:BoundField DataField="MinutesElapsed"   HeaderText="Mins Elapsed" />
                    <asp:TemplateField HeaderText="">
                        <ItemTemplate>
                            <asp:Label runat="server"
                                CssClass='<%# "status-" + Eval("Status") %>'
                                Text='<%# Eval("IsOverdue").ToString() == "True" ? "OVERDUE" : "" %>' />
                        </ItemTemplate>
                    </asp:TemplateField>
                </Columns>
            </asp:GridView>

        </div>
        <script>
            // Clock update - inline JS, "works fine"
            function updateClock() {
                var now = new Date();
                document.getElementById('clock').innerHTML = now.toLocaleTimeString();
            }
            setInterval(updateClock, 1000);
            updateClock();
        </script>
    </form>
</body>
</html>
