#!/bin/bash
#SBATCH --job-name=simple_policy_peract
#SBATCH --nodes 1
#SBATCH --ntasks 1
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:a100:1
#SBATCH --hint=nomultithread
#SBATCH --time=48:00:00
#SBATCH --mem=40G
#SBATCH --output=slurm_logs/%j.out
#SBATCH --error=slurm_logs/%j.out
#SBATCH -p willow 
#SBATCH -A willow

set -x
set -e

module purge
pwd; hostname; date

cd $HOME/codes/robot-3dlotus

. $HOME/miniconda3/etc/profile.d/conda.sh
conda activate gembench

export MASTER_PORT=$(expr 10000 + $(echo -n $SLURM_JOBID | tail -c 4))
export WORLD_SIZE=$(($SLURM_NNODES * $SLURM_TASKS_PER_NODE))
master_addr=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)
export MASTER_ADDR=$master_addr

ulimit -n 2048

output_dir=data/experiments/peract/3dlotus/v1

rot_type=euler_disc
npoints=4096
pos_bin_size=15

srun python genrobo3d/train/train_simple_policy.py \
    --exp-config genrobo3d/configs/rlbench/simple_policy_ptv3.yaml \
    output_dir ${output_dir} \
    TRAIN.num_epochs null TRAIN.num_train_steps 300000 \
    TRAIN.log_steps 1000 TRAIN.save_steps 10000 TRAIN.val_steps 10000 \
    TRAIN.train_batch_size 8 TRAIN.val_batch_size 8 \
    VAL_DATASET.use_val False \
    TRAIN_DATASET.rm_robot box_keep_gripper \
    TRAIN_DATASET.num_points ${npoints} \
    TRAIN_DATASET.all_step_in_batch True \
    TRAIN_DATASET.instr_embed_type all \
    TRAIN_DATASET.xyz_shift center \
    TRAIN_DATASET.xyz_norm False \
    TRAIN_DATASET.rot_type ${rot_type} \
    TRAIN_DATASET.sample_points_by_distance False \
    TRAIN_DATASET.taskvar_file assets/taskvars_peract.json  \
    TRAIN_DATASET.data_dir data/peract/train/keysteps_bbox_pcd/voxel1cm \
    TRAIN_DATASET.instr_embed_file data/peract/train/keysteps_bbox_pcd/instr_embeds_clip.npy \
    TRAIN_DATASET.taskvar_instr_file assets/taskvars_instructions_peract.json \
    TRAIN_DATASET.include_last_step False \
    TRAIN_DATASET.use_height True \
    TRAIN_DATASET.augment_pc True \
    TRAIN_DATASET.aug_max_rot 45 \
    TRAIN_DATASET.rm_pc_outliers False \
    MODEL.ptv3_config.drop_path 0.0 MODEL.ptv3_config.attn_drop 0.1 MODEL.ptv3_config.proj_drop 0.1 \
    MODEL.action_config.dropout 0.2 \
    MODEL.action_config.voxel_size 0.01 \
    MODEL.action_config.reduce max \
    MODEL.action_config.dim_actions 7 MODEL.action_config.rot_pred_type ${rot_type} \
    MODEL.action_config.pos_pred_type heatmap_disc \
    MODEL.action_config.pos_heatmap_temp 0.1 \
    MODEL.ptv3_config.in_channels 7 \
    MODEL.ptv3_config.pdnorm_only_decoder False \
    MODEL.ptv3_config.qk_norm True \
    MODEL.ptv3_config.scaled_cosine_attn False MODEL.ptv3_config.enable_flash True \
    MODEL.action_config.max_steps 30 \
    MODEL.ptv3_config.enc_depths "[1, 1, 1, 1, 1]" \
    MODEL.ptv3_config.dec_depths "[1, 1, 1, 1]" \
    MODEL.ptv3_config.enc_channels "[64, 128, 256, 512, 768]" \
    MODEL.ptv3_config.dec_channels "[128, 128, 256, 512]" \
    MODEL.action_config.use_step_id False \
    MODEL.action_config.use_ee_pose False \
    MODEL.loss_config.pos_weight 1 MODEL.loss_config.rot_weight 1 \
    TRAIN_DATASET.pos_type disc VAL_DATASET.pos_type disc \
    TRAIN_DATASET.pos_heatmap_type dist VAL_DATASET.pos_heatmap_type dist \
    TRAIN_DATASET.pos_bins ${pos_bin_size} VAL_DATASET.pos_bins ${pos_bin_size} \
    MODEL.action_config.pos_bins ${pos_bin_size} \
    TRAIN_DATASET.pos_heatmap_no_robot True VAL_DATASET.pos_heatmap_no_robot True \
    MODEL.action_config.txt_reduce attn \
    MODEL.model_class SimplePolicyPTV3CA \
    MODEL.ptv3_config.pdnorm_bn False MODEL.ptv3_config.pdnorm_ln False \
    MODEL.ptv3_config.pdnorm_adaptive False