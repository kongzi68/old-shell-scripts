#!/bin/bash
# 越南用于补充查询未生成的日报数据
# 使用方法：
## sh daily_scripts_name.sh '2017-02-16'

starttime=$1

cd /data/3gh/dataplatform/normal
echo "application start : " `date`
python -m process.update.LoginUpdate
echo "LoginUpdate finished : " `date`
#sleep 600
python -m process.ossmid.distinct
echo "distinct finished : " `date`
#sleep 120
# 比如starttime='2017-02-16',那么是计算的2017-02-15日的充值总数据
# python -m process.allgo.all daily 2017-02-16
python -m process.allgo.all daily $starttime 
echo "all finished : " `date`
#python -m process.channel.channel_pro
echo "channel finished : " `date`
python -m process.ossmid.vipupdate
echo "vip update finished : " `date`
python -m process.ossmid.characterupdate
#sleep 600
echo 'character finished : ' `date`
#python -m process.gamerecord.shopbuy
##
# 比如今天是2017-02-26，那么下面这句将运行的数据是从2017-02-16~2017-02-26期间的呢？
# python -m process.gamerecord.recordstatistic ShopBuy ShopBuy_daily itemid count,costgold,costsw '2017-02-16'
##
python -m process.gamerecord.recordstatistic ShopBuy ShopBuy_daily itemid count,costgold,costsw $starttime
echo "shopbuy finished : " `date`
#python -m process.gamerecord.treasure
python -m process.gamerecord.recordstatistic RecvTreasureHunting Treasure_daily package_content_type,package_content_id package_content_count $starttime 
echo "treasure finished : " `date`
#python -m process.gamerecord.vipshopbuy
python -m process.gamerecord.recordstatistic VIPShopBuy VIPShopBuy_daily goodid,cost count $starttime
echo "vipshopbuy finished : " `date`
#python -m process.gamerecord.consumereturn
echo "consume return finished : " `date`
#python -m process.gamerecord.dailygift
python -m process.gamerecord.recordstatistic DailyGift DailyGift_daily gift_type,cash_reduce_count $starttime
echo "daily gift finished : " `date`
python -m process/gamerecord/recordstatistic ReduceCash ReduceCash_daily src_type,cashtype count $starttime 
echo "daily reduce cash finished : " `date`
python -m process/gamerecord/recordstatistic AddCash AddCash_daily src_type,cashtype count $starttime 
echo "daily add cash finished : " `date`
python -m process/gamerecord/recordstatistic TaskFinish TaskFinish_daily taskid $starttime 
python -m process/gamerecord/recordstatistic JingMaiLevelUp JingMaiLevelUp_daily type $starttime 
python -m process/gamerecord/recordstatistic Train Train_daily type,char_type cost1,cost2 $starttime 
python -m process/gamerecord/recordstatistic BuyEnergy BuyEnergy_daily cost $starttime 
python -m process/gamerecord/recordstatistic WipeOut WipeOut_daily transid,difflv num $starttime 
python -m process/gamerecord/recordstatistic NPCShopBuy NPCShopBuy_daily goodtype,goodid count,cost1,cost2,cost3,cost4 $starttime 
python -m process/gamerecord/recordstatistic RecvGuildAward RecvGuildAward_daily recvtype bg,ubg,sw $starttime 
python -m process/gamerecord/recordstatistic Recharge Recharge_daily ubg $starttime 
python -m process/gamerecord/recordstatistic OpenPayChest OpenPayChest_daily cost2 cost1 $starttime 
python -m process/gamerecord/recordstatistic PickWinePackage PickWinePackage_daily price,warrior_type $starttime 
python -m process/gamerecord/recordstatistic ReclosePayChest ReclosePayChest_daily cost2 $starttime 
python -m process/gamerecord/recordstatistic AddEnergy AddEnergy_daily src count $starttime 
python -m process/gamerecord/recordstatistic ReduceEnergy ReduceEnergy_daily src count $starttime 
python -m process/gamerecord/recordstatistic ConsumeReturn ConsumeReturn_daily consume_reward_level $starttime 
python -m process/gamerecord/recordstatistic ShopCityConsumeReward ShopCityConsumeReward_daily consume_reward_level $starttime 
python -m process/gamerecord/recordstatistic RechargeGift RechargeGift_daily consume_reward_level $starttime 
python -m process/gamerecord/recordstatistic RechargeMember RechargeMember_daily ubg $starttime 
python -m process/gamerecord/recordstatistic EnterArena EnterArena_daily times,cost,type $starttime 
python -m process/gamerecord/recordstatistic FeedMountPray FeedMountPray_daily PrayCount,FodderType prayMoney $starttime 
cd ~
