#!/bin/bash

# ELK内存计算器 - 根据服务器总内存自动计算单节点和3节点集群的内存分配

# 获取服务器总内存（MB）
get_total_memory_mb() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux系统
        local total_mem_kb=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
        echo $((total_mem_kb / 1024))  # 转换为MB
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS系统
        local total_mem_bytes=$(sysctl -n hw.memsize)
        echo $((total_mem_bytes / 1024 / 1024))  # 转换为MB
    else
        # 其他系统，默认返回8192MB (8GB)
        echo 8192
    fi
}

# 计算单节点模式内存分配
calculate_single_node_memory() {
    local total_memory_mb=$1
    local elk_percentage=${2:-50}  # 默认50%给Elasticsearch
    
    # 计算Elasticsearch内存（总内存的50%）
    local es_memory_mb=$((total_memory_mb * elk_percentage / 100))
    
    # 将Elasticsearch内存分为JVM堆内存（最多不超过32GB，且不超过系统内存的50%）
    local es_heap_mb=$es_memory_mb
    if [ $es_heap_mb -gt 32768 ]; then  # 32GB上限
        es_heap_mb=32768
    elif [ $es_heap_mb -gt $((total_memory_mb / 2)) ]; then
        es_heap_mb=$((total_memory_mb / 2))
    fi
    
    # 保证堆内存为偶数GB值
    es_heap_mb=$((es_heap_mb / 1024 * 1024))  # 转换为整数GB
    
    # 如果计算出的堆内存小于1GB，则设为1GB
    if [ $es_heap_mb -lt 1024 ]; then
        es_heap_mb=1024
    fi
    
    echo $es_heap_mb
}

# 计算3节点集群模式内存分配
calculate_cluster_memory() {
    local total_memory_mb=$1
    local elk_percentage=${2:-50}  # 默认50%给Elasticsearch集群
    
    # 计算Elasticsearch集群总内存（总内存的50%）
    local es_cluster_memory_mb=$((total_memory_mb * elk_percentage / 100))
    
    # 3个节点平分内存
    local es_per_node_mb=$((es_cluster_memory_mb / 3))
    
    # 将每个节点内存分为JVM堆内存（最多不超过32GB，且不超过该节点分配内存的50%）
    local es_heap_mb=$es_per_node_mb
    if [ $es_heap_mb -gt 32768 ]; then  # 32GB上限
        es_heap_mb=32768
    elif [ $es_heap_mb -gt $((es_per_node_mb / 2)) ]; then
        es_heap_mb=$((es_per_node_mb / 2))
    fi
    
    # 保证堆内存为偶数GB值
    es_heap_mb=$((es_heap_mb / 1024 * 1024))  # 转换为整数GB
    
    # 如果计算出的堆内存小于1GB，则设为1GB
    if [ $es_heap_mb -lt 1024 ]; then
        es_heap_mb=1024
    fi
    
    echo $es_heap_mb
}

# 生成docker-compose配置文件的内存设置
generate_compose_config() {
    local total_memory_mb=$1
    local mode=$2  # single 或 cluster
    
    if [ "$mode" = "single" ]; then
        local es_heap_mb=$(calculate_single_node_memory $total_memory_mb)
        local es_heap_gb=$((es_heap_mb / 1024))
        
        echo "# 单节点模式内存配置"
        echo "# 服务器总内存: $((total_memory_mb / 1024)) GB"
        echo "# Elasticsearch JVM堆内存: ${es_heap_gb}GB (-Xms${es_heap_gb}g -Xmx${es_heap_gb}g)"
        echo ""
        echo "Environment settings for docker-compose.yml:"
        echo "  ES_JAVA_OPTS: \"-Xms${es_heap_gb}g -Xmx${es_heap_gb}g\""
        
    elif [ "$mode" = "cluster" ]; then
        local es_heap_mb=$(calculate_cluster_memory $total_memory_mb)
        local es_heap_gb=$((es_heap_mb / 1024))
        
        echo "# 3节点集群模式内存配置"
        echo "# 服务器总内存: $((total_memory_mb / 1024)) GB"
        echo "# 每个Elasticsearch节点JVM堆内存: ${es_heap_gb}GB (-Xms${es_heap_gb}g -Xmx${es_heap_gb}g)"
        echo ""
        echo "Environment settings for docker-compose.cluster.yml:"
        echo "  ES_JAVA_OPTS: \"-Xms${es_heap_gb}g -Xmx${es_heap_gb}g\"  # for each node"
    fi
}

# 主函数
main() {
    echo "ELK内存分配计算器"
    echo "=================="
    
    # 获取参数
    if [ $# -eq 0 ]; then
        # 自动获取系统内存
        TOTAL_MEMORY_MB=$(get_total_memory_mb)
        MODE="both"
    elif [ $# -eq 1 ]; then
        # 用户指定了内存大小（GB）
        TOTAL_MEMORY_MB=$(($1 * 1024))
        MODE="both"
    elif [ $# -eq 2 ]; then
        # 用户指定了内存大小（GB）和模式
        TOTAL_MEMORY_MB=$(($1 * 1024))
        MODE=$2
    else
        echo "用法:"
        echo "  $0                           # 自动检测系统内存并计算两种模式"
        echo "  $0 <内存大小GB>              # 根据指定内存计算两种模式"
        echo "  $0 <内存大小GB> <模式>       # 根据指定内存和模式计算 (single|cluster|both)"
        exit 1
    fi
    
    case $MODE in
        "single")
            echo ""
            generate_compose_config $TOTAL_MEMORY_MB "single"
            ;;
        "cluster")
            echo ""
            generate_compose_config $TOTAL_MEMORY_MB "cluster"
            ;;
        "both")
            echo ""
            generate_compose_config $TOTAL_MEMORY_MB "single"
            echo ""
            echo "----------------------------------------"
            echo ""
            generate_compose_config $TOTAL_MEMORY_MB "cluster"
            ;;
        *)
            echo "错误: 模式必须是 'single', 'cluster' 或 'both'"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"