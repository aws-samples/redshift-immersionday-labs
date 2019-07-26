# Lab 7 - Amazon Redshift Operations

In this lab, we step through some common operations a Redshift Administrator may have to do to maintain their Redhshift environment.

## Contents
* [Before You Begin](#before-you-begin)
* [Event Subscriptions](#event-subscriptions)
* [Cluster Encryption](#cluster-encryption)
* [Cross Region Replication](#cross-region-replication)
* [Elastic Resize](#elastic-resize)
* [Release Rollback](#release-rollback)
* [Before You Leave](#before-you-leave)

## Before You Begin
This lab assumes you have launched a Redshift cluster.  If you have not launched a cluster, see [LAB 1 - Creating Redshift Clusters](../lab1/README.md).

## Event Subscriptions
1. Navigate to your Redshift Events page.  Notice the *Events* involved with creating the cluster.  
```
https://console.aws.amazon.com/redshift/home?#events:cluster=
```
<img src=images/Events.png style="border: 1px solid;box-shadow: 5px 10px #888888;">
2. Click on the *Subscriptions* tab and then click on the *Create Event Subscription* button.
<img src=images/CreateSubscription_0.png style="border: 1px solid;box-shadow: 5px 10px #888888;">
3. Create a subscription for *any* severity *management* notification on *any cluster*.   Notice the types of event on the right you will recieve a notification for.
<img src=images/CreateSubscription_1.png style="border: 1px solid;box-shadow: 5px 10px #888888;">
4. Name the subscription *CLusterManagement* and click *Next*.
<img src=images/CreateSubscription_2.png style="border: 1px solid;box-shadow: 5px 10px #888888;">
5. Select the *Create New Topic* tab and enter the topic name *ClusterManagement*.  Add your email address and click *Add Recipient*.  Finally, click *Create*.
<img src=images/CreateSubscription_3.png style="border: 1px solid;box-shadow: 5px 10px #888888;">
6. You will recieve an email shortly.  Click on the *Confirm subscription* link in the email.
<img src=images/ConfirmSubscriptionEmail.png style="border: 1px solid;box-shadow: 5px 10px #888888;">
7. The link should take you to a final confirmation page confirming the subscription.
<img src=images/SubscriptionConfirmed.png style="border: 1px solid;box-shadow: 5px 10px #888888;">

## Cluster Encryption
Note: This portion of the lab will take ~45 minutes to complete based on the data loaded in [LAB 2 - Creating Redshift Clusters](../lab2/README.md).  Please plan accordingly.

1. Navigate to your Redshift Cluster list.  Select your cluster and click on *Cluster* -> *Modify Cluster*.
```
https://console.aws.amazon.com/redshift/home?#cluster-list
```
<img src=images/ModifyCluster.png style="border: 1px solid;box-shadow: 5px 10px #888888;">
2. Select *KMS* for the database encryption and then click *Modify*.
<img src=images/EnableKMS.png style="border: 1px solid;box-shadow: 5px 10px #888888;">
4. Notice your cluster enters a *resizing* status.  The process of encrypting your cluster is similar to resizing your cluster using the classic resize method.  All data is read, encrypted and re-written. During this time, the cluster is still avialable for read queries, but not write queries.
<img src=images/Resizing.png style="border: 1px solid;box-shadow: 5px 10px #888888;">
5. You should also receive an email notification about the cluster resize because of the event subscription we setup earlier.
<img src=images/ResizeNotification.png style="border: 1px solid;box-shadow: 5px 10px #888888;">

## Cross Region Replication
1. Navigate to your Redshift Cluster list.  Select your cluster and click on *Backup* -> *Configure Cross-region snapshots*.
```
https://console.aws.amazon.com/redshift/home?#cluster-list
```
<img src=images/ConfigureCRR_0.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>
2. Select the *Yes* radio button to enable the copy.  Select the destination region of *us-east-2*.  Because the cluster is encrypted you must establish a grant in the other region to allow the snapshot to be re-encrypted.  Select *No* for the Existing Snapshot Copy Grant.  Name the Snapshot Copy Grant with the value *SnapshotGrant*.
<img src=images/ConfigureCRR_1.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>
3. To demonstrate the cross-region replication, initiate a manual backup.  Click on *Backup* -> *Take Snapshot*.
<img src=images/Snapshot_0.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>
4. Name the snapshot *CRRBackup* and click *Create*.
<img src=images/Snapshot_1.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>
5. Navigate to your list of snapshots and notice the snapshot is being created.
```
https://console.aws.amazon.com/redshift/home?#snapshots:id=;cluster=
```
<img src=images/Snapshot_2.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>
6. Wait for the snapshot to finish being created.  The status will be *available*.
<img src=images/Snapshot_3.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>
7. Navigate to the us-east-2 region by select *Ohio* from the region drop down, or navigate to the following link.  Notice that the snapshot is available and is in a *copying* status.
```
https://us-east-2.console.aws.amazon.com/redshift/home?region=us-east-2#snapshots:id=;cluster=
```
<img src=images/Snapshot_4.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>

## Elastic Resize
Note: This portion of the lab will take ~15 minutes to complete based on the data loaded in [LAB 2 - Creating Redshift Clusters](../lab2/README.md).  Please plan accordingly.
1. Navigate to your Redshift Cluster list.  Select your cluster and click on *Cluster* -> *Resize*.  Note, if you don't see your cluster, you may have to change the *Region* drop-down.
<img src=images/Resize_0.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>
2. Ensure the *Elastic Resize* radio is selected.  Choose the *New number of nodes*, and click *Resize*.
<img src=images/Resize_1.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>
3. When the resize operation begins, you'll see the Cluster Status of *prep-for-resize*.
<img src=images/Resize_2.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>
4. When the operation completes, you'll see the Cluster Status of *available* again.
<img src=images/Resize_3.png style="border: 1px solid;box-shadow: 5px 10px #888888;"><br>

## Before You Leave
If you are done using your cluster, please think about decommissioning it to avoid having to pay for unused resources.
