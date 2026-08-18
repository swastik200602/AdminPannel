using Dapper;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Data.Common;

namespace AdminPannel.Logic
{
    public class AppData
    {
        private string _connection;
        public AppData()
        {
            _connection = ConnectHelper.Connect;
        }
        public async Task<string> ExecuteAsync(string StoredProc, object parameter)
        {
            int Res = 0;
            try
            {

                using (var con = new SqlConnection(_connection))
                {
                    await con.OpenAsync();
                    Res = await con.ExecuteAsync(StoredProc, parameter, null, null, commandType: CommandType.StoredProcedure);
                    await con.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            if (Res > 0)
                return "Success";
            else
                return "Failed";
        }
        // Common method to execute Proc sync
        public string Executesync(string StoredProc, object parameter)
        {
            int Res = 0;
            try
            {

                using (var con = new SqlConnection(_connection))
                {
                    con.Open();
                    Res = con.Execute(StoredProc, parameter, null, null, commandType: CommandType.StoredProcedure);
                    con.Close();
                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            if (Res > 0)
                return "Success";
            else
                return "Failed";
        }

        // Common method to query from Proc
        public async Task<dynamic> QueryAsync(string StoredProc, object parameter)
        {
            var Result = (dynamic)null;
            try
            {
                using (var con = new SqlConnection(_connection))
                {
                    await con.OpenAsync();
                    Result = await con.QueryAsync(StoredProc, parameter, null, commandTimeout: 10, commandType: CommandType.StoredProcedure);
                    await con.CloseAsync();
                }
                return Result;
            }
            catch (Exception ex)
            {
                throw ex;
            }
        }
        // common method to query with execute 
        public object QueryWithExecuteAsync(string StoredProc, object parameter)
        {
            var Result = (dynamic)null;
            try
            {
                using (var con = new SqlConnection(_connection))
                {
                    con.Open();
                    Result = con.Query(StoredProc, parameter, null, commandType: CommandType.StoredProcedure).FirstOrDefault();
                    con.Close();

                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            return Result;
        }
        public object QueryWithWithoutStoreProcedureAsync2(string query)
        {
            var result = (dynamic)null;
            try
            {
                using (var con = new SqlConnection(_connection))
                {
                    con.Open();
                    result = con.Query(query);
                    con.Close();
                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            return result;
        }
        public object QueryWithWithoutStoreProcedureAsync(string query)
        {
            var result = (dynamic)null;
            try
            {
                using (var con = new SqlConnection(_connection))
                {
                    con.Open();
                    result = con.Query(query).FirstOrDefault();
                    con.Close();

                    result = new
                    {
                        Role = "",
                        ResultStatus = "t",
                        Message = "Success"
                    };

                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            return result;
        }

        public T SelectModel<T>(string proc, object param)
        {
            var result = (dynamic)null;
            try
            {
                using (var con = new SqlConnection(_connection))
                {
                    con.Open();
                    result = con.Query<T>(proc, param, commandType: CommandType.StoredProcedure).FirstOrDefault();
                    con.Close();
                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
            }
            return result;
        }
        public async Task<List<T>> SelectModelListAsync<T>(string proc, object param)
        {
            var result = (dynamic)null;
            try
            {
                using (var con = new SqlConnection(_connection))
                {
                    con.Open();
                    result = await con.QueryAsync<T>(proc, param, commandType: System.Data.CommandType.StoredProcedure);
                    con.Close();
                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
            }
            return result;
        }

        public List<T> SelectModelList<T>(string proc, object param)
        {
            using var con = new SqlConnection(_connection);
            con.Open();
            return con.Query<T>(
                    proc,
                    param,
                    commandType: CommandType.StoredProcedure)
                .ToList();
        }
        public (T1, List<T2>) QueryMultiple<T1, T2>(string procName, object param = null)
        {
            using (IDbConnection con = new SqlConnection(_connection))
            {
                con.Open();

                using (var multi = con.QueryMultiple(procName,
                                                     param,
                                                     commandType: CommandType.StoredProcedure))
                {
                    var list1 = multi.Read<T1>().FirstOrDefault();
                    var list2 = multi.Read<T2>().ToList();

                    return (list1, list2);
                }
            }
        }


    }


}

