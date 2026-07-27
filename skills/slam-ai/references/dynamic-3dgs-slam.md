# Dynamic-Scene 3DGS-SLAM Landscape

Verified on `2026-07-27` against the local merged corpus, local full text,
arXiv, Crossref, OpenAlex, official CVF pages, DOI landing pages, and public
project/code repositories.

## Contents

- [When To Use This Reference](#when-to-use-this-reference)
- [Scope And Inclusion Rule](#scope-and-inclusion-rule)
- [Search Audit](#search-audit)
- [Task Taxonomy](#task-taxonomy)
- [Priority Reading Set](#priority-reading-set)
- [Boundary And Adjacent Work](#boundary-and-adjacent-work)
- [Published-Only Or Secondary Coverage Gaps](#published-only-or-secondary-coverage-gaps)
- [Identity And Deduplication Hazards](#identity-and-deduplication-hazards)
- [Benchmark Comparison Rules](#benchmark-comparison-rules)
- [Cross-Cutting Observability Prior Art](#cross-cutting-observability-prior-art)
- [Technical Synthesis](#technical-synthesis)
- [Required Metadata For Future Papers](#required-metadata-for-future-papers)
- [Local Query Recipe](#local-query-recipe)
- [Maintenance Procedure](#maintenance-procedure)

## When To Use This Reference

Use this reference when the user asks for:

- dynamic-scene 3DGS-SLAM papers or baselines
- anti-dynamic Gaussian SLAM versus dynamic/4D reconstruction
- moving-object, object-level, or non-rigid Gaussian SLAM
- a benchmark comparison across TUM RGB-D, Bonn, Wild-SLAM, surgical, or 4D
  datasets
- a novelty check for a dynamic 3DGS-SLAM paper idea
- code availability, runtime, sensor-input, or online-causality comparisons

Do not answer these questions from method names alone. In this literature,
`dynamic` may mean removing moving pixels, retaining dynamic objects, learning
a deformation field, camera motion, or merely changing an optimization
schedule. These are different tasks.

## Scope And Inclusion Rule

A work belongs in the primary SLAM tables only when all of the following hold:

1. Input camera poses are unknown at runtime.
2. The system estimates a camera trajectory rather than consuming a complete
   externally optimized trajectory as fixed input.
3. A Gaussian or Gaussian-adjacent map is updated incrementally.
4. Dynamic-scene handling affects tracking, mapping, or both.

An external VO/SLAM front end may still form a system-level SLAM pipeline, but
record it as `pose_map_coupling=external` or `loose`; do not describe it as
tightly coupled Gaussian pose-map optimization.

Treat camera pose as a first-class output. A method that optimizes camera poses
only as nuisance variables for point tracking or view synthesis, without a SLAM
trajectory evaluation, belongs in the boundary table rather than a SLAM
leaderboard.

Keep the following outside the primary table:

- offline dynamic/4D Gaussian reconstruction with known poses
- methods that require the full future sequence before producing a map
- static 3DGS-SLAM papers that only mention dynamic scenes as a limitation
- `MotionGS`, where motion filtering is a frame-tracking/keyframe mechanism,
  not a moving-object model
- `EndoGSLAM`, which performs surgical RGB-D Gaussian SLAM but assumes the
  observed tissue is largely static and lists deformation handling as future
  work; its `100+ FPS` figure is rendering speed, not SLAM throughput
- dynamic neural-field SLAM without a Gaussian map; retain it only as a
  baseline family

## Search Audit

This is a scoped literature landscape, not a claim of perfect systematic
exhaustiveness.

- Local merged corpus: `1787` identity-deduplicated papers, `59112` chunks,
  and `0` unmapped files as of the current corpus snapshot.
- Local semantic queries covered dynamic Gaussian SLAM, moving objects,
  static/dynamic maps, 4D reconstruction, non-rigid tracking, uncertainty,
  semantics, and motion probability.
- Broad arXiv query:
  `all:Gaussian AND all:SLAM AND (dynamic OR motion OR deformable OR non-rigid)`
  returned `118` records on `2026-07-27` before screening.
- The narrower arXiv query using the exact phrase `Gaussian Splatting`
  returned `76` records before screening.
- Crossref title/DOI search recovered published-only papers missing from the
  arXiv result, including multiple papers with the same `DGS-SLAM` name.
- OpenAlex and official publisher/CVF pages were used to verify abstracts and
  publication identities. Semantic Scholar returned HTTP `429`, so it was not
  used as evidence.
- Crossref resolved all `30/30` DOI occurrences (`28` unique DOIs).
- Public project and GitHub pages were checked for actual source availability;
  a placeholder repository is not counted as released code.

Screening retained `47` identities: `35` in the priority reading set and `12`
published-only or secondary records awaiting the same depth of review. Evidence
depth is not uniform. The runtime and protocol caveats below come from local or
public full text. Where only an official abstract was available, the table does
not infer runtime or protocol details beyond that abstract; lower-priority
abstract-only records remain in the coverage-gap table.

## Task Taxonomy

| Class | Output contract | What dynamics do | Comparable only with |
|---|---|---|---|
| `A static-output` | Camera trajectory plus a clean static map | Detect, mask, down-weight, or prune moving content | Other static-output methods with the same sensor and evaluation mask |
| `B dual-map/object` | Static map plus dynamic Gaussians, object tracks, or motion state | Preserve and model moving objects | Other object-aware methods with equivalent object supervision |
| `C non-rigid` | Camera trajectory plus a continuous deformation model | Jointly estimate camera motion and non-rigid scene motion | Other non-rigid methods on the same surgical/object protocol |
| `D 4DGS-SLAM` | Camera trajectory plus an explicitly time-varying Gaussian field | Model a spatiotemporal scene representation | Other causal 4D methods with the same online/final protocol |
| `E offline reconstruction` | Dynamic/4D scene with known or globally optimized poses | Reconstruct motion after pose acquisition | Offline reconstruction only; exclude from SLAM rankings |

Classes `B`, `C`, and `D` can overlap. Record the primary output contract and
add secondary tags rather than forcing every paper into one flat leaderboard.

## Priority Reading Set

### A. Dynamic suppression and static-map reconstruction

| Paper | Verified identity/status | Input and pose path | Dynamic mechanism and output | Audit note |
|---|---|---|---|---|
| [DG-SLAM](https://arxiv.org/abs/2411.08373) | NeurIPS 2024; [code](https://github.com/fudan-zvg/DG-SLAM) | RGB-D; DROID-VO initialization plus Gaussian optimization | OneFormer and multi-view depth warp generate masks; dynamic content is removed; static map | Paper reports `2 FPS`, but the reported tracking and segmentation modules total about `808.9 ms/frame`; later dense BA is post-tracking |
| [DGS-SLAM (Kong et al.)](https://arxiv.org/abs/2411.10722) | arXiv; [project shell](https://github.com/kmk97/DGS-SLAM) | RGB-D; online pose/map optimization | Track Anything plus cross-keyframe photometric consistency; static map with loop-aware window selection | Reported `1.60 FPS` excludes segmentation; ATE is evaluated on keyframes and rendering masks dynamic pixels; the public repository has no implementation |
| [Gassidy](https://doi.org/10.1109/ICRA55743.2025.11127678) | ICRA 2025 | RGB-D | Instance components and photometric/geometric rendering-loss flow are iteratively classified; static map | TUM and Bonn dominate the evidence; no verified public implementation |
| [GARAD-SLAM](https://doi.org/10.1109/ICRA55743.2025.11128757) | ICRA 2025; [arXiv](https://arxiv.org/abs/2502.03228); [project shell](https://github.com/DrLi-Ming/GARAD-SLAM) | RGB-D | CRF over Gaussian attributes plus sparse-flow verification; penalizes dynamic Gaussians instead of irreversible deletion | Static-output anti-dynamic method; TUM/Bonn; the public repository contains no implementation |
| [WildGS-SLAM](https://doi.org/10.1109/CVPR52734.2025.01070) | CVPR 2025; [arXiv](https://arxiv.org/abs/2504.03886); [code](https://github.com/GradientSpaces/WildGS-SLAM) | Monocular RGB with learned depth and DINOv2 features | Learned pixel uncertainty down-weights/removes dynamics in DBA and mapping; static map | Introduces Wild-SLAM MoCap/iPhone; uncertainty can conflate motion, boundaries, blur, and poor input quality |
| [Dy3DGS-SLAM](https://doi.org/10.1109/ICRA55743.2025.11127324) | ICRA 2025; [arXiv](https://arxiv.org/abs/2506.05965) | Monocular RGB with DepthAnythingV2 and learned VO | Probabilistic fusion of optical-flow and depth masks; transient content is excluded; static map | `17 FPS` is tracking only; mapping is about `430.5 ms`; mapping evidence is mainly qualitative |
| [UP-SLAM](https://arxiv.org/abs/2505.22335) | ICRA 2026 metadata on arXiv; [project](https://aczheng-cai.github.io/up_slam.github.io/) | RGB-D; parallel tracking/mapping | Training-free multimodal residual uncertainty, probabilistic octree, DINO features; artifact-free static map | Compare only against RGB-D static-output methods; project page is not equivalent to released source |
| [DyPho-SLAM](https://arxiv.org/abs/2509.00741) | ICME 2025 Oral in arXiv metadata | RGB-D; Photo-SLAM/ORB-SLAM3 base | YOLO prior-image mask refinement and adaptive feature selection; static map | Real-time claim is tied to the feature-based implementation; TUM/Bonn only |
| [DyGS-SLAM (Hu et al.)](https://doi.org/10.1109/ICCV51701.2025.00892) | ICCV 2025; [CVF paper](https://openaccess.thecvf.com/content/ICCV2025/html/Hu_DyGS-SLAM_Real-Time_Accurate_Localization_and_Gaussian_Reconstruction_for_Dynamic_Scenes_ICCV_2025_paper.html) | RGB-D feature/Gaussian pipeline | Geometry-and-appearance motion checks plus box correction identify known and unknown movers; static background map | Distinct from the Remote Sensing paper with the same acronym |
| [MPDG-SLAM](https://doi.org/10.1109/IROS60139.2025.11247059) | IROS 2025 | RGB-D | YOLO prior plus per-Gaussian motion probability propagated to front-end tracking and MP-guided pruning; static map | Claims over `30 FPS` on a high-end GPU and only suggests future mobile deployment |
| [SLAM-X](https://doi.org/10.1145/3746027.3754971) | ACM MM 2025; [repository](https://github.com/DrLi-Ming/SLAM-X) | Plug-in for NeRF-SLAM and GS-SLAM | Zero-shot segmentation plus adaptive sparse flow generates dynamic masks for host tracking/mapping | Not a standalone SLAM method; repository still says source will be released soon |
| [LVD-GS](https://arxiv.org/abs/2510.22669) | arXiv; [project](https://zwk0901.github.io/LVD-GS2025/) | RGB plus LiDAR; KISS-ICP and multiple foundation models | Open-world segmentation, residual constraints, and uncertainty generate masks; dynamic objects are eliminated | Despite `joint dynamic modeling` wording, the output is a static map; baseline inputs and evaluated frame ranges are not matched |
| [Rad-GS](https://doi.org/10.1109/LRA.2025.3630875) | IEEE RA-L 2025; [arXiv](https://arxiv.org/abs/2511.16091); [placeholder](https://github.com/IAMXII/Rad-GS) | 4D radar plus monocular RGB; internal radar-to-Gaussian map tracking | Doppler residuals, enhanced-radar octree propagation, and EfficientSAM mask movers; detections are excluded from a static 3DGS map | `4D` denotes radar, not a 4D Gaussian field. Outdoor refinement has bounded delay; reported `0.037/0.082 ms` modules have an apparent unit inconsistency and omit full preprocessing cost |
| [RGD-SLAM](https://doi.org/10.1016/j.patcog.2026.113071) | Pattern Recognition 2026; [code](https://github.com/00Haocheng/RGD-SLAM) | RGB-D | Motion masks and adaptive pose weights in the front end; visibility-aware static mapping | Code is public, but the released implementation is currently single-threaded |
| [DGS-SLAM (Jia et al.)](https://doi.org/10.1109/TCSVT.2025.3645351) | IEEE TCSVT 2026 issue metadata | RGB-D | Object association, long-window motion checks, local 3DGS repair, static-keyframe selection; static map | One of three distinct `DGS-SLAM` identities; always cite DOI and first author |
| [DAGS-SLAM](https://arxiv.org/abs/2602.21644) | arXiv 2026 | RGB-D | Temporally updated motion probability per Gaussian and uncertainty-triggered YOLO invocation; static map | Resource-aware design, but its mobile/edge claim is motivation rather than measured deployment |
| [GGD-SLAM](https://arxiv.org/abs/2604.12837) | ICRA 2026 in arXiv metadata | Monocular RGB; Metric3D-v2 predicted depth and modified DROID DBA; Gaussian mapping is downstream/loose | A DAVIS-trained sequential motion model, occlusion filling, and distractor-aware loss produce a static map | `No depth input` means no depth sensor. Wild-SLAM evidence is qualitative only, runtime is not reported, and dynamic reconstruction remains future work |
| [MoPe](https://arxiv.org/abs/2606.29237) | RSS 2026 Workshop in arXiv metadata; [code](https://github.com/chloeqxq/MoPe) | Monocular WildGS-SLAM extension; a shared posterior softly couples DBA and mapping, but GS rendering does not optimize pose | Geometry-warped Bayesian history preserves dynamic identity through pauses/occlusions; final output is static | `65.3 ms/frame` is tracking plus mapping only and excludes final Gaussian cleanup; semantic cost is unclear, and gains concentrate on stop-and-go motion |
| [DL-SLAM](https://arxiv.org/abs/2607.01860) | ACM MM 2026 in the full text | Monocular RGB with DROID, Metric3D, RAM, Grounding DINO, MobileSAMv2, and CLIP | Pixel/object probabilities retain transiently static objects for tracking, prune them from the map, and receive indirect map-to-probability-to-DBA feedback | Reported modules sum to `898.5 ms/frame`, not a verified end-to-end total; rendering is on training views and object trajectories are not modeled |

### B. Dynamic-object and 4D output

| Paper | Verified identity/status | Input and coupling | Dynamic representation | Audit note |
|---|---|---|---|---|
| [PG-SLAM](https://doi.org/10.1109/TRO.2025.3619073) | IEEE T-RO 2025; [arXiv](https://arxiv.org/abs/2411.15800) | RGB-D; static and dynamic constraints contribute to localization | Static background plus dynamic rigid items and non-rigid humans/quadrupeds using shape priors and Gaussian appearance/geometry | Strong object-aware system, but prior shape models make it a different supervision regime from class-agnostic masking |
| [ODHSR](https://doi.org/10.1109/CVPR52734.2025.02033) | CVPR 2025; [arXiv](https://arxiv.org/abs/2504.13167); [project shell](https://github.com/eth-ait/ODHSR) | Monocular RGB; reconstruction-based camera tracking and human-pose optimization initialized by WHAM/SMPL priors | Separate scene and articulated-human Gaussians plus a time-pose deformation network; primary class `B`, secondary class `C` | EMDB/NeuMan evaluate camera, human pose, and NVS. Training is about `0.141 FPS`, rendering `85 FPS`, and a final all-keyframe `100`-epoch refinement is separate; the repository still promises source code |
| [DynaGSLAM](https://doi.org/10.1109/WACV61042.2026.00240) | WACV 2026; [code](https://github.com/BlarkLee/DynaGSLAM_official) | RGB-D; DynoSAM provides poses | Separate static/dynamic Gaussians and Hermite-spline object motion prediction | System-level SLAM but loose coupling: Gaussian mapping does not feed back to camera trajectory; about `1.25 FPS` end to end |
| [4D Gaussian Splatting SLAM](https://doi.org/10.1109/ICCV51701.2025.02320) | ICCV 2025; [arXiv](https://arxiv.org/abs/2503.16710); [code](https://github.com/yanyan-li/4DGS-SLAM) | RGB-D; incremental unknown-pose tracking | Static/dynamic Gaussian split, sparse control points, MLP deformation, optical-flow supervision | Some sequences require manually chosen dynamic initialization; late-appearing dynamics are not inserted; `1500` final refinement iterations must be separated from online results |
| [D4DGS-SLAM / Dynamics-aware 4DGS-SLAM](https://doi.org/10.1109/IROS60139.2025.11245901) | IROS 2025; [arXiv](https://arxiv.org/abs/2504.04844) | RGB-D; long-term LEAP point tracks guide pose estimation | Direct 4D Gaussians with point dynamics, visibility, and reliability | Reports about `1.5 FPS` on Bonn and `0.9 FPS` on TartanAir-Shibuya; strict causal use of the temporal LEAP window needs code-level verification |
| [JPG-SLAM](https://doi.org/10.1109/ICRA55743.2025.11127881) | ICRA 2025 | RGB-D | Isotropic points support pose estimation; 3D Gaussians model static regions and 4D Gaussians model dynamic regions | Joint point-Gaussian representation is not directly comparable to pure differentiable-rendering trackers |
| [CAD-SLAM / former ADD-SLAM](https://arxiv.org/abs/2505.19420) | arXiv 2025 | RGB-D; consistency-aware tracking and mapping | Static background plus object-level temporal Gaussians; bidirectional tracklets | The local `ADD-SLAM` and `CAD-SLAM` files are byte-identical; count once. Module times total about `2.2 s` on A100, so it is not real time |
| [ProDyG](https://arxiv.org/abs/2509.17864) | arXiv 2025; [project shell](https://github.com/cs-vision/ProDyG) | RGB or RGB-D; Splat-SLAM DBA estimates unknown poses, while the dynamic map follows them with loose coupling | Residual-flow/SAM2 masks separate the scene; CoTracker3 tracks initialize progressively extended Motion Scaffolds and dynamic Gaussians | Bonn/TUM use ATE; iPhone uses PSNR/SSIM/LPIPS with preprocessed motion masks. It is online but explicitly not real time, struggles with re-entry and large viewpoint changes, and its repository contains only README/media |
| [D2GSLAM](https://arxiv.org/abs/2512.09411) | arXiv 2025 | RGB-D | Geometric-prompt separation; static 3D Gaussians plus dynamic 4D Gaussians; motion consistency | Uses both static geometry and dynamic motion for progressive pose refinement; evaluate static and dynamic outputs separately |
| [Dream-SLAM](https://arxiv.org/abs/2602.21967) | arXiv 2026; code promised after acceptance | Monocular RGB; BA and loop closure, extended with active exploration | Mask R-CNN plus diffusion-generated cross-spatio-temporal constraints; per-pixel static/dynamic Gaussians, with foreground also contributing to localization | TUM/Bonn evaluate ATE/NVS; Gibson/HM3D planning scenes add synthetic humans. Full localization/mapping is `0.65 s/frame`, including about `0.3 s` for dreaming; this is not a like-for-like passive baseline |
| [RU4D-SLAM](https://openaccess.thecvf.com/content/CVPR2026F/html/Zhao_RU4D-SLAM_Reweighting_Uncertainty_in_Gaussian_Splatting_SLAM_for_4D_Scene_CVPRF_2026_paper.html) | CVPR Findings 2026; [arXiv](https://arxiv.org/abs/2602.20807); [code](https://github.com/CNU-Bot-Group/ru4dslam) | Monocular RGB plus Metric3D predicted depth; uncertainty-aware DROID-style DBA, with no direct dynamic-map pose residual | Reweighted uncertainty, deformation nodes, motion-blur/exposure rendering, and adaptive temporal opacity form a 4D output | Runtime is not reported, real-time operation is future work, and strict causal online use is not established; do not label it RGB-D |
| [Flow4DGS-SLAM](https://arxiv.org/abs/2604.22339) | CVPR 2026 Highlight; [code](https://github.com/wangys16/Flow4DGS-SLAM) | RGB-D plus RAFT and YOLOv9; static GS refines pose while the dynamic branch follows | Category-agnostic residual flow is unioned with YOLOv9 masks; explicit temporal centers, scene flow, and GMM opacity/rotation model dynamics | `6285 ms` is per mapping step and `0.50 FPS` is keyframe-frequency-derived; final rendering also uses `1500` color-refinement iterations |

### C. Non-rigid and surgical Gaussian SLAM

| Paper | Status | Representation/input | Why it is separate |
|---|---|---|---|
| [4DTAM](https://arxiv.org/abs/2505.22859) | CVPR 2025; [code](https://github.com/muskie82/4dtam) | RGB-D, 2D surface Gaussians, MLP warp field | It is true joint non-rigid SLAM but uses surface/2D Gaussians rather than strict 3DGS; about `1.5 FPS` plus a roughly minute-long global optimization; main quantitative geometry result is synthetic Sim4D |
| [EndoFlow-SLAM](https://arxiv.org/abs/2506.21420) | MICCAI 2025; `A/surgical` | Endoscopic Gaussian SLAM with flow-constrained pose/map optimization | It handles breathing-induced motion as a constraint but does not expose an explicit non-rigid deformation state; specialized datasets make it unsuitable for TUM/Bonn rankings |
| [NRGS-SLAM](https://arxiv.org/abs/2602.17182) | arXiv 2026 | Monocular non-rigid endoscopic SLAM with deformation-aware 3DGS | Evaluated on StereoMIS, Hamlyn, and C3VDv2; domain-specific depth/scale assumptions must be recorded |
| [Track2Map](https://arxiv.org/abs/2607.08408) | MICCAI 2026 on the [project page](https://track2map.github.io/) | Stereo surgical RGB with FoundationStereo and CoTracker3 anchors; a monocular Depth Anything V2 variant is also reported | Only `Pose Init=None` is no-prior SLAM; clean/noisy-prior runs are reconstruction/refinement. StereoMIS is the main evaluation and runtime is about `6 s/frame`; optical-axis/whole-tissue motion, weak texture, and large tool occlusion can break the motion gate |

## Boundary And Adjacent Work

These works are technically relevant but should not be counted in the primary
dynamic 3DGS-SLAM set or mixed into its quantitative rankings.

| Work | Why it is outside the primary set | Correct use |
|---|---|---|
| [MotionGS](https://arxiv.org/abs/2405.11129) | `Motion filter` selects/tracks frames according to camera motion; it does not detect or model moving objects | Static Gaussian-SLAM/keyframe baseline |
| [Go-SLAM](https://arxiv.org/abs/2409.16944) | Adds open-vocabulary object IDs, queries, and navigation to a Gaussian map, but no object-motion state changes tracking or mapping; evaluation is on static Replica scenes | Semantic/object-navigation baseline, not dynamic SLAM |
| [DynOMo](https://arxiv.org/abs/2409.02104) | Online unposed monocular dynamic Gaussian reconstruction jointly optimizes camera poses, but the task and metrics are 2D/3D point tracking rather than SLAM trajectory estimation | Adjacent online reconstruction and motion-representation baseline |
| [VG-Mapping](https://arxiv.org/abs/2510.09962) | Updates a semi-static Gaussian map using externally supplied VINS-Mono poses; the paper leaves full SLAM as future work | Long-term map-maintenance baseline |
| [EndoGSLAM](https://arxiv.org/abs/2403.15124) and [Endo-2DTAM](https://arxiv.org/abs/2501.19319) | Endoscopic SLAM systems with static 3D/2D Gaussian maps and no explicit deformation state | Surgical static-map baselines for EndoFlow/NRGS/Track2Map |
| Offline dynamic 3DGS/4DGS families | Consume known or globally optimized poses and often the complete sequence | Representation, deformation, or rendering baseline only; never a SLAM localization result |

## Published-Only Or Secondary Coverage Gaps

These records were found through DOI/publisher or current survey lists but do
not all have a fully audited local PDF. Keep them in a `needs_full_text_review`
queue rather than silently treating them as equivalent evidence.

| Work | Stable identity | Current classification |
|---|---|---|
| DGS-SLAM: A Visual Dense SLAM Based on Gaussian Splatting in Dynamic Environments | [ICRA 2025 DOI](https://doi.org/10.1109/ICRA55743.2025.11128821) | A; semantic 3D Gaussians, distance-based pruning, static map |
| SDD-SLAM | [RA-L DOI](https://doi.org/10.1109/LRA.2025.3561565) | A; semantic object-level active/passive dynamic removal |
| DynaGS-SLAM | [ICME 2025 DOI](https://doi.org/10.1109/ICME59968.2025.11209853) | A; semantic masks plus rendered-background replacement |
| BDGS-SLAM | [Sensors DOI](https://doi.org/10.3390/s25216641) | A; YOLO/Bayesian per-Gaussian motion probability and multi-view recovery |
| DOGL-SLAM | [RA-L DOI](https://doi.org/10.1109/LRA.2025.3641131); [project shell](https://github.com/NKU-MobFly-Robotics/DOGL-SLAM) | A plus object-level semantic map; joint Gaussian-landmark tracking and hierarchical dynamic filtering; source is unavailable and the referenced Docker image is opaque |
| Dynamic SLAM With 3-D Gaussian Splatting Supporting Monocular Sensing | [IEEE Sensors Journal DOI](https://doi.org/10.1109/JSEN.2025.3560481) | A; verify full text before detailed comparison |
| DyGS-SLAM: Realistic Map Reconstruction in Dynamic Scenes Based on Double-Constrained Visual SLAM | [Remote Sensing DOI](https://doi.org/10.3390/rs17040625) | A; distinct from the ICCV DyGS-SLAM |
| Dynamic 3D Gaussian SLAM via motion suppression and incremental optimization | [ESWA DOI](https://doi.org/10.1016/j.eswa.2026.131329) | A; verify full text before detailed comparison |
| Semantic perception 3DGS-SLAM system for dynamic scenes (GSV-SLAM) | [Engineering Research Express DOI](https://doi.org/10.1088/2631-8695/ae50b0) | A; YOLOv11, geometric consistency, static map |
| RtDGS-SLAM | [conference DOI](https://doi.org/10.1109/AIBDF67964.2025.11440902) | A; depth-guided masking and static reconstruction |
| DynaSplaTAM | [SPIE DOI](https://doi.org/10.1117/12.3113817) | A; lightweight semantic-depth mask on SplaTAM |
| LCD-Splat | [Sensors DOI](https://doi.org/10.3390/s26092669) | A plus loop closure; Mask R-CNN, multi-view geometry, 3DGS submaps |

## Identity And Deduplication Hazards

### ADD-SLAM and CAD-SLAM are one paper

The following local files have the same SHA-256 for both PDF and extracted
Markdown:

- `0059_[SLAM]_ADD-SLAM Adaptive Dynamic Dense SLAM with Gaussian Splatting.*`
- `recent5y_2505.19420_CAD-SLAM_Consistency-Aware_Dynamic_SLAM_with_Dynamic-Static_Decoupled_Mapping.*`

The current arXiv identity is `2505.19420`, titled `CAD-SLAM`. Older surveys
and paper lists call it `ADD-SLAM`. Store `ADD-SLAM` as an alias and count one
paper.

### DGS-SLAM names collide

Never cite `DGS-SLAM` without first author and identifier:

1. Kong et al., `Gaussian Splatting SLAM in Dynamic Environment`,
   [arXiv:2411.10722](https://arxiv.org/abs/2411.10722).
2. Chen et al., `A Visual Dense SLAM Based on Gaussian Splatting in Dynamic
   Environments`, [ICRA DOI](https://doi.org/10.1109/ICRA55743.2025.11128821).
3. Jia et al., `Robust Visual SLAM With 3D Gaussian Splatting in Dynamic
   Environments`, [TCSVT DOI](https://doi.org/10.1109/TCSVT.2025.3645351).

`DG-SLAM` (NeurIPS 2024) is a fourth, separate identity.

Do not inherit the `ICRA 2025` label for the Kong paper from third-party
paper lists: its current arXiv record says `Preprint, Under review`, and no
matching DOI was found. Never deduplicate these records by acronym alone.

### Other near-collisions

- `DyGS-SLAM` has both a Remote Sensing 2025 paper and a distinct ICCV 2025
  paper.
- `DynaGSLAM` (object motion modeling) and `DynaGS-SLAM` (dynamic removal) are
  different systems.
- Normalize `D2GSLAM`, `D^2GSLAM`, and `D$^2$GSLAM` to arXiv `2512.09411`.

## Benchmark Comparison Rules

Do not build a single SOTA ranking from reported headline numbers. At minimum,
stratify by these fields:

1. Sensor input: RGB-D, monocular plus predicted depth, RGB plus LiDAR, RGB plus
   4D radar, stereo, or external kinematics.
2. Pose source: internal optimizer, learned VO initialization, external SLAM,
   fixed prior, or post-optimized trajectory.
3. Output: static background, static/dynamic dual map, object trajectory,
   deformation field, or full 4D scene.
4. Trajectory scope: all frames versus keyframes only.
5. Rendering split: training views, held-out views, masked static pixels, or
   complete dynamic frames.
6. Runtime scope: renderer only, tracking only, tracking plus mapping, or full
   pipeline including segmentation and post-refinement.
7. Causality: strict online, bounded causal window, future-frame window, or
   full-sequence refinement.

The common datasets do not close these gaps:

- TUM RGB-D and Bonn are useful for camera ATE but do not provide a complete
  real 4D geometry, scene-flow, and object-trajectory ground truth.
- Wild-SLAM adds less staged monocular scenes but its iPhone subset lacks
  reliable trajectory ground truth for some sequences.
- Static-output PSNR after masking moving objects is not comparable to full
  dynamic-frame PSNR from a 4D model.
- 4DGS-SLAM, Flow4DGS-SLAM, 4DTAM, ODHSR, ProDyG, and MoPe use final
  optimization or cleanup stages that must be reported separately from online
  outputs.
- A method described as `class-agnostic` may still use YOLO, SAM, Grounded SAM,
  DINO, or another pretrained prior. Record the actual dependency.

## Cross-Cutting Observability Prior Art

Dynamic-scene novelty checks must also include classical feature-selection and
visual-estimation work. The following papers are available as full text in the
local `top_venue_reference_expansion` corpus:

| Work | Established mechanism | Novelty consequence for dynamic Gaussian SLAM |
|---|---|---|
| Zhang and Vela, [Good Features to Track for Visual SLAM](https://doi.org/10.1109/CVPR.2015.7298743), CVPR 2015 | Uses observability rank and minimum singular value, incremental SVD, and approximately submodular greedy feature selection | Rank or minimum-eigenvalue gating and selecting a small tracking subset are not new by themselves |
| Carlone and Karaman, [Attention and Anticipation in Fast Visual-Inertial Navigation](https://arxiv.org/abs/1610.03344), ICRA 2017 | Selects visual cues under a budget using future-window information-matrix objectives and submodular greedy optimization | Fisher information, look-ahead selection, and budgeted cue admission are established tools |
| Zhao and Vela, [Good Feature Selection for Least Squares Pose Optimization in VO/VSLAM](https://arxiv.org/abs/1905.07807), IROS 2018 | Applies Max-logDet selection to pose-Jacobian row blocks and integrates it into visual SLAM | Delta-logdet feature selection over a pose Hessian is not a standalone contribution |
| Zhao and Vela, [Good Feature Matching](https://arxiv.org/abs/2001.00714), T-RO 2020 | Actively selects valuable map-to-frame matches under latency constraints | A budgeted minimal recovery set has a strong classical nearest neighbor |
| Zhao, Smith, and Vela, [Good Graph to Optimize](https://arxiv.org/abs/2008.10123), 2020 | Dynamically allocates a bundle-adjustment budget and selects a condition-preserving subgraph | Budget-aware BA scheduling and information-preserving graph reduction are established |

For dynamic measurements, a raw matrix `sum(J^T W J)` is camera information
only when the residual model is correct. A genuinely moving point evaluated
under a static-world model can increase minimum eigenvalue or log-determinant
while biasing the camera pose. Treat object motion as a nuisance state and use
the camera Schur complement
`H_cc - H_co (H_oo + Lambda_o)^-1 H_oc` before claiming foreground utility.

The defensible dynamic-specific boundary is therefore narrower than a generic
Hessian gate:

1. measure post-intervention observability after the actual mask, extractor,
   spatial allocation, matching, and robust weighting stages;
2. marginalize object-motion uncertainty before scoring foreground camera
   information; and
3. admit only the smallest causal foreground set needed for tracking while
   keeping it outside the persistent static Gaussian map.

DyPho-SLAM already compensates feature count according to mask area. DL-SLAM
already lets transiently static evidence support tracking while pruning it from
the map. PG-SLAM and D2GSLAM already use modeled foreground constraints for
pose refinement. Combining these ingredients without the motion-marginalized
information test is likely to be judged incremental.

## Technical Synthesis

The field has progressed through four main shifts:

1. Binary removal: semantic or geometric masks protect camera tracking and
   produce clean static maps.
2. Soft temporal state: uncertainty or motion probability lets the system use
   stationary intervals without permanently fusing transient objects.
3. Explicit dynamics: object-level Gaussians, deformation nodes, and 4D
   Gaussian fields retain motion and can contribute constraints to tracking.
4. Dynamic utility: PG-SLAM and Dream-SLAM begin to use modeled foreground
   constraints for localization, while Dream-SLAM also connects the dynamic map
   to active exploration instead of treating dynamics only as reconstruction.

The remaining high-value gaps are:

- observable separation of ego-motion and object motion without heavy priors
- tightly coupled dynamic-map feedback whose observability is explicit, rather
  than a dynamic mapper that only consumes front-end poses
- stop/start motion, object re-entry, long occlusion, and topology change
- dynamic loop closure and globally consistent 4D map correction
- long-horizon object lifecycle and memory-bounded map management
- video-rate causal 4D optimization rather than renderer-only real-time claims
- a unified real benchmark with camera trajectory, dynamic geometry, scene
  flow, object identity/trajectory, held-out views, and synchronized timing
- fair monocular comparisons that expose learned depth/VO dependencies

## Required Metadata For Future Papers

Every newly reviewed dynamic paper should record:

```text
paper_key
title
aliases
arxiv_id
doi
publication_status
local_source
task_class
sensor_input
depth_source
pose_source
pose_map_coupling
causal
future_frame_dependency
dynamic_detector
dynamic_output
post_refinement
runtime_scope
runtime_hardware
runtime_units
trajectory_scope
render_split
pose_eval_protocol
map_eval_protocol
datasets
code_url
code_state
alias_of
evidence_level
reviewed_on
```

Use `code_state` values such as `released`, `partial`, `placeholder`,
`promised`, or `none_found`. Use `evidence_level=full_text` only after reading
the method, experiments, and limitations rather than only the abstract.

## Local Query Recipe

Use the merged reviewed corpus and run separate short queries:

```powershell
& C:\Users\Administrator\.venvs\streetcuda310\Scripts\python.exe `
  C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\slam_skill_cli.py query `
  "dynamic gaussian slam" `
  --out-dir C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\merged_corpus_review\turbovec-out `
  --top-k 20 --search-k 500 --dedupe-papers

& C:\Users\Administrator\.venvs\streetcuda310\Scripts\python.exe `
  C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\slam_skill_cli.py query `
  "4D gaussian SLAM dynamic reconstruction" `
  --out-dir C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\merged_corpus_review\turbovec-out `
  --top-k 20 --search-k 500 --dedupe-papers

& C:\Users\Administrator\.venvs\streetcuda310\Scripts\python.exe `
  C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\slam_skill_cli.py query `
  "non-rigid gaussian tracking mapping surgery" `
  --out-dir C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\merged_corpus_review\turbovec-out `
  --top-k 15 --search-k 500 --dedupe-papers
```

Then inspect the relevant local full text. Do not infer class, online behavior,
or runtime scope from the retrieved chunk alone.

## Maintenance Procedure

1. Search the local merged corpus first.
2. Search arXiv with both exact `Gaussian Splatting` and broad `Gaussian`
   variants so renamed or publisher-only records are not lost.
3. Search Crossref by exact title to recover DOI-only proceedings and journals.
4. Resolve identity by DOI, then arXiv ID, then normalized title plus authors.
5. Check aliases against the collision list before counting a paper.
6. Stage a missing public PDF for review; do not silently bulk-import it into
   the root corpus.
7. Read method, experiments, runtime definition, limitations, and supplement
   before promoting a record to the primary table.
8. Verify that a code repository contains source rather than only a README.
9. Recheck publication status and links when refreshing the landscape.
10. Recompute primary/gap counts and resolve every DOI and external link.
11. Record the verification date and preserve the old reviewed snapshot.
