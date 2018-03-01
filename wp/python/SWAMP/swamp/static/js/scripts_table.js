/**
 * Created by kongxiaolin on 2018/1/15.
 */


var $table = $('#tb_departments');

$(function () {
    $table.bootstrapTable({
        url: '/admin/scripts/_scripts_table_data/',
        method: 'get',                      //请求方式（*）
        dataType: 'json',
        toolbar: '#toolbar',                //工具按钮用哪个容器
        striped: true,                      //是否显示行间隔色
        cache: false,                       //是否使用缓存，默认为true，所以一般情况下需要设置一下这个属性（*）
        pagination: true,                   //是否显示分页（*）
        sortName: 'id',
//      sortable: true,                     //是否启用排序
        sortOrder: "desc",                   //排序方式
        sidePagination: "client",           //分页方式：client客户端分页，server服务端分页（*）
        pageNumber: 1,                       //初始化加载第一页，默认第一页
        pageSize: 20,                       //每页的记录行数（*）
        pageList: [20, 40, 60],        //可供选择的每页的行数（*）
        search: true,                       //是否显示表格搜索，此搜索是客户端搜索，不会进服务端，所以，个人感觉意义不大
        showColumns: true,                  //是否显示所有的列
        showRefresh: true,                  //是否显示刷新按钮
        minimumCountColumns: 2,             //最少允许的列数
        clickToSelect: true,                //是否启用点击选中行
        singleSelect: true,                 //单选
        height: 800,                        //行高，如果没有设置height属性，表格自动根据记录条数觉得表格高度
        uniqueId: "id",                     //每一行的唯一标识，一般为主键列
        showToggle: true,                    //是否显示详细视图和列表视图的切换按钮
        cardView: false,                    //是否显示详细视图
        detailView: false,                   //是否显示父子表
        columns: [{
            checkbox: true
        }, {
            field: 'id',
            title: 'ID',
            sortable: true,
            align: 'center'
        }, {
            field: 'custom_name',
            title: '自定义平台名称',
            sortable: true,
            align: 'center'
        }, {
            field: 'server_ip',
            title: '服务器IP',
            sortable: true,
            align: 'center'
        }, {
            field: 'server_user',
            title: '服务器用户名',
            align: 'center'
        }, {
            field: 'server_port',
            title: '服务器端口',
            align: 'center'
        }, {
            field: 'server_password',
            title: '服务器密码',
            align: 'center'
        }, {
            field: 'scripts_path',
            title: '脚本所在路径',
            halign: 'center'
        }, {
            field: 'scripts_name',
            title: '脚本名',
            sortable: true,
            halign: 'center'
        }, {
            field: 'scripts_log',
            title: '脚本日志文件',
            sortable: true,
            halign: 'center'
        }
/*
        {
        title: '功能',
        field: 'id',
        align: 'center',
        formatter: function (value, row, index) {
          var e = '<a href="#" onclick="edit(\'' + row.id + '\')">编辑</a> ';  //row.id为每行的id
          var d = '<a href="#" onclick="del(\'' + row.id + '\')">删除</a> ';
          return e + d;
        }}
*/

        ]
    });

    $("#addRecord").click(function(){
        var $custom_name = $('#id_custom_name'), $server_ip = $('#id_server_ip'),
            $server_user = $('#id_server_user'), $server_port = $('#id_server_port'),
            $server_password = $('#id_server_password'), $scripts_path = $('#id_scripts_path'),
            $scripts_name = $('#id_scripts_name'), $scripts_log = $('#id_scripts_log');
        var datas = {};
        datas['custom_name'] = $custom_name.val();
        datas['server_ip'] = $server_ip.val();
        datas['server_user'] = $server_user.val();
        datas['server_port'] = $server_port.val();
        datas['server_password'] = $server_password.val();
        datas['scripts_path'] = $scripts_path.val();
        datas['scripts_name'] = $scripts_name.val();
        datas['scripts_log'] = $scripts_log.val();
        // console.log(data.custom_name);
        // console.log('对象：', datas);
        // console.log(typeof datas);
        // console.log('对象：', datas);
        // alert("custom_name:" + $("#id_custom_name").val() + "server_ip:" +$("#id_server_ip").val());
        // 检查input的值不为空？
        var t_check = {
            custom_name: $custom_name.attr('placeholder'),
            server_ip: $server_ip.attr('placeholder'),
            server_user: $server_user.attr('placeholder'),
            server_port: $server_port.attr('placeholder'),
            server_password: $server_password.attr('placeholder'),
            scripts_path: $scripts_path.attr('placeholder'),
            scripts_name: $scripts_name.attr('placeholder'),
            scripts_log: $scripts_log.attr('placeholder')
        };
        //用forEach()进行遍历
        var ret_value = Object.keys(datas).some(function (tz) {
            // console.log("datas ", tz, ": ", datas[tz]);
            if(!datas[tz] && tz != 'server_password'){
                alert(t_check[tz] + '：值为空，请重新输入.');
                $("#id_"+tz).focus();  // 选择器用变量
                return true;
            }
        });
        if( ret_value == true) {
            return false;
        }
        // 保存数据
        $.ajax({
            type: 'POST',
            url: '/admin/scripts/_get_datas/',
            data: JSON.stringify({'datas': datas}),
            dataType: 'json',
            contentType: 'application/json; charset=UTF-8',
            beforeSend:function(){
//          $("#tip").html("<span style='color:blue'>正在处理...</span>");
                return true;
            },
            success:function(data){
                console.log(data);
                if(data.ret == true )
                {
//            $("#tip").html("<span style='color:blueviolet'>添加成功！</span>");
                    alert("新增数据保存成功");
                    setTimeout(function(){
                        location.reload();    // 要延迟执行的代码块
                    }, 1000);               // 延迟1秒
                }
                else
                {
//            $("#tip").html("<span style='color:red'>失败，请重试！</span>");
                    alert('保存失败');
                }
            },
            error:function()
            {
                alert('请求出错');
            },
            complete:function()
            {
//          $('#acting_tips').hide();
            }
        });
    });

    $("#alterRecord").click(function(){
        var $custom_name = $('#id_custom_name0'), $server_ip = $('#id_server_ip0'),
            $server_user = $('#id_server_user0'), $server_port = $('#id_server_port0'),
            $server_password = $('#id_server_password0'), $scripts_path = $('#id_scripts_path0'),
            $scripts_name = $('#id_scripts_name0'), $scripts_log = $('#id_scripts_log0');
        var datas = {};
        datas['id'] = $('#id_id0').val();
        datas['custom_name'] = $custom_name.val();
        datas['server_ip'] = $server_ip.val();
        datas['server_user'] = $server_user.val();
        datas['server_port'] = $server_port.val();
        datas['server_password'] = $server_password.val();
        datas['scripts_path'] = $scripts_path.val();
        datas['scripts_name'] = $scripts_name.val();
        datas['scripts_log'] = $scripts_log.val();
        // console.log(data.custom_name);
        // console.log('对象：', datas);
        // console.log(typeof datas);
        // 检查input的值不为空？
        var t_check = {
            custom_name: $custom_name.attr('placeholder'),
            server_ip: $server_ip.attr('placeholder'),
            server_user: $server_user.attr('placeholder'),
            server_port: $server_port.attr('placeholder'),
            server_password: $server_password.attr('placeholder'),
            scripts_path: $scripts_path.attr('placeholder'),
            scripts_name: $scripts_name.attr('placeholder'),
            scripts_log: $scripts_log.attr('placeholder')
        };
        //用forEach()进行遍历
        var ret_value = Object.keys(datas).some(function (tz) {
            // console.log("datas ", tz, ": ", datas[tz]);
            if(!datas[tz] && tz != 'server_password'){
                alert(t_check[tz] + '：值为空，请重新输入.');
                $("#id_"+tz+"0").focus();  // 选择器用变量
                return true;
            }
        });
        if( ret_value == true) {
            return false;
        }
        // 保存数据
        $.ajax({
            type: 'POST',
            url: '/admin/scripts/_get_save_datas/',
            data: JSON.stringify({'datas': datas}),
            dataType: 'json',
            contentType: 'application/json; charset=UTF-8',
            beforeSend:function(){
                return true;
            },
            success:function(data){
                // console.log(data);
                if(data.ret == true )
                {
                    alert("修改成功！");
                    setTimeout(function(){
                        location.reload();    // 要延迟执行的代码块
                    }, 1000);               // 延迟1秒
                }
                else
                {
                    alert('修改失败');
                }
            },
            error:function()
            {
                alert('请求出错');
            }
        });
    });
});


// 加载需要修改的数据
function get_edit_info()
{
    var getselectdata = $table.bootstrapTable('getSelections');
    if(getselectdata.length == 0)
    {
        alert('请选择需要修改的数据！');
        location.reload();
        return false;
    }
    var json_data = eval(getselectdata);
    // console.log(json_data);
    // console.log(json_data[0].custom_name);
    $("#id_id0").val(json_data[0].id);
    $("#id_custom_name0").val(json_data[0].custom_name);
    $("#id_server_ip0").val(json_data[0].server_ip);
    $("#id_server_user0").val(json_data[0].server_user);
    $("#id_server_port0").val(json_data[0].server_port);
    $("#id_server_password0").val(json_data[0].server_password);
    $("#id_scripts_path0").val(json_data[0].scripts_path);
    $("#id_scripts_name0").val(json_data[0].scripts_name);
    $("#id_scripts_log0").val(json_data[0].scripts_log);
    return true;
}

// 删除数据
function delete_info()
{
    var getselectdata = $table.bootstrapTable('getSelections');
    if(getselectdata.length == 0)
    {
        alert('请选择需要删除的数据！');
        location.reload();
        return false;
    }
    var json_data = eval(getselectdata);
    console.log(json_data);
    console.log(json_data[0].id);

    $.ajax({
        type: 'POST',
        url: '/admin/scripts/_delete_datas/',
        data: JSON.stringify({'datas': json_data[0].id}),
        dataType: 'json',
        contentType: 'application/json; charset=UTF-8',
        beforeSend:function(){
            return true;
        },
        success:function(data){
            console.log(data);
            if(data.ret == true )
            {
                alert("OK！");
                setTimeout(function(){
                    location.reload();    // 要延迟执行的代码块
                }, 1000);               // 延迟1秒
            }
            else
            {
                alert('操作失败');
            }
        },
        error:function()
        {
            alert('请求出错');
        }
    });
}

