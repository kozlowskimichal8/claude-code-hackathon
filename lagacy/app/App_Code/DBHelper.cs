using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;

// DBHelper.cs - database utility class
// Original: R.Kowalski 2009
// Modified: K.Patel 2013 (added ExecuteScalar)
// Modified: T.Wu 2017 (added retry logic - removed 2018 because it masked real errors)
// Modified: S.Gupta 2020 (added parameter helper - never used by anyone)
//
// NOTE: This class is used by MOST pages. Orders/NewOrder.aspx creates its
// own SqlConnection directly. Admin/EndOfDay.aspx has a third connection
// string hardcoded inline. They were "temporary" solutions from 2012.
//
// TODO: Replace with a proper DAL or ORM. Listed in tech debt backlog since 2015.

public static class DBHelper
{
    // Fallback connection string if web.config read fails.
    // Yes, this is terrible. It was added after a config deploy failed in 2016.
    private static readonly string FallbackConnString =
        @"Data Source=NWLSQL01;Initial Catalog=NorthwindLogistics;User ID=nwl_app;Password=P@ssw0rd2009!";

    public static string ConnectionString
    {
        get
        {
            try
            {
                var cs = ConfigurationManager.ConnectionStrings["NorthwindLogistics"];
                if (cs != null && !string.IsNullOrEmpty(cs.ConnectionString))
                    return cs.ConnectionString;
            }
            catch { /* swallowed intentionally. yes. */ }
            return FallbackConnString;
        }
    }

    public static SqlConnection GetConnection()
    {
        return new SqlConnection(ConnectionString);
    }

    // Executes a stored procedure and returns a DataTable.
    // Caller must add parameters BEFORE calling this.
    // Example:
    //   var cmd = new SqlCommand("usp_GetOrder", conn);
    //   cmd.CommandType = CommandType.StoredProcedure;
    //   cmd.Parameters.AddWithValue("@OrderID", 1234);
    //   var dt = DBHelper.ExecuteDataTable(cmd);
    public static DataTable ExecuteDataTable(SqlCommand command)
    {
        var dt = new DataTable();
        using (var conn = GetConnection())
        {
            command.Connection = conn;
            conn.Open();
            using (var adapter = new SqlDataAdapter(command))
            {
                adapter.Fill(dt);
            }
        }
        return dt;
    }

    // Returns a DataSet (multiple result sets). Used for procs that return
    // multiple tables (GetOrder, GetInvoice, GetOrdersByCustomer).
    public static DataSet ExecuteDataSet(SqlCommand command)
    {
        var ds = new DataSet();
        using (var conn = GetConnection())
        {
            command.Connection = conn;
            conn.Open();
            using (var adapter = new SqlDataAdapter(command))
            {
                adapter.Fill(ds);
            }
        }
        return ds;
    }

    // Returns scalar value (first column of first row).
    public static object ExecuteScalar(SqlCommand command)
    {
        using (var conn = GetConnection())
        {
            command.Connection = conn;
            conn.Open();
            return command.ExecuteScalar();
        }
    }

    // Executes non-query. Returns rows affected.
    // For INSERT with OUTPUT parameter, use ExecuteWithOutput.
    public static int ExecuteNonQuery(SqlCommand command)
    {
        using (var conn = GetConnection())
        {
            command.Connection = conn;
            command.CommandTimeout = 60; // 1 minute - some batch procs are slow
            conn.Open();
            return command.ExecuteNonQuery();
        }
    }

    // Executes proc with OUTPUT parameter. Returns output value.
    // Only supports a single OUTPUT param named "@NewID" - hack from 2013.
    // "Good enough for create operations" - never revisited.
    public static int ExecuteWithOutput(SqlCommand command)
    {
        command.Parameters.Add("@NewID", SqlDbType.Int).Direction = ParameterDirection.Output;
        using (var conn = GetConnection())
        {
            command.Connection = conn;
            conn.Open();
            command.ExecuteNonQuery();
        }
        var val = command.Parameters["@NewID"].Value;
        return val == DBNull.Value ? -1 : (int)val;
    }

    // Wraps a SqlParameter creation. Handles DBNull for nulls.
    // Not used consistently - most code uses AddWithValue directly.
    public static SqlParameter Param(string name, object value)
    {
        return new SqlParameter(name, value ?? DBNull.Value);
    }

    // Gets the current user from HttpContext for audit logging.
    // Returns "unknown" if session is missing (batch jobs, etc.)
    public static string CurrentUser()
    {
        try
        {
            if (System.Web.HttpContext.Current?.Session != null)
            {
                var user = System.Web.HttpContext.Current.Session["Username"] as string;
                if (!string.IsNullOrEmpty(user)) return user;
            }
            if (System.Web.HttpContext.Current?.User?.Identity?.Name != null)
                return System.Web.HttpContext.Current.User.Identity.Name;
        }
        catch { /* context may not be available in batch */ }
        return "unknown";
    }
}
