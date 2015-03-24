function [ output ] = coco_dpm_test( dpm_model, dpm_thresh, dataDir, dataType, imgIds, outputFile )
% coco_dpm_test is a wrapper of the DPM code running a trained dpm model 
% on a set of images specified by their COCO ids.
% Detections are:  
%  - saved in the following JSON format: 
% [{'image_id': int, 'cateogry_id': int, 'bbox': [x, y, w, h], 'score': float}]
%  - returned in an output cell array
%
% USAGE:
%  $ > load VOC2010/bicycle_final.mat
%  $ > output = coco_dpm_test( model, -0.5, '../coco_dir', 'val2014', [388258], './bike_dpm_detections_coco.json' )
%
% INPUTS:
%  - dpm_model      - model trained with dpm  
%  - dpm_thresh     - threshold for detection of the trained model
%  - dataDir        - path to the coco main directory
%  - dataType       - train, test or validation type of data
%  - imgIds         - array containing the COCO Ids of the images to use
%  - outputFile     - path to the output file
%
% OUTPUTS:
%  - output         - struct array containing an element for each detection
%
% Code written by Matteo Ruggero Ronchi, 2015.
% Licensed under the Simplified BSD License [see coco/license.txt]

output = struct();

%% set dpm model parameters
if nargin < 2
    % if the threshold is not included we use the one in the model
    dpm_thresh = dpm_model.thresh;
end

%% initialize COCO api for instance annotations
if nargin < 3
    dataDir = '../';
end

if nargin < 4
    dataType = 'test2014';
end

annFile=sprintf('%s/annotations/instances_%s.json',dataDir,dataType);
if(~exist('coco','var')), coco=CocoApi(annFile); end

%% recover Ids of images to use for testing
if nargin < 5
    % if a list of IDs is not specified test on all the images
    imgIds = coco.getImgIds();
end
nImages = length( imgIds );

%% set maximum detection variables
% maximum of 100 detections per image are allowed
maxDetections = 100;
counter = 0;

%% adjuste difference in category names between COCO and PASCAL 
switch dpm_model.class
    case 'aeroplane'
        dpm_class = 'airplane';
    case 'diningtable'
        dpm_class = 'dining table';
    case 'motorbike'
        dpm_class = 'motorcycle';
    case 'pottedplant'
        dpm_class = 'potted plant';
    case 'sofa'
        dpm_class = 'couch';
    case 'tvmonitor'
        dpm_class = 'tv';
    otherwise
        dpm_class = dpm_model.class;
end     
category_id = coco.getCatIds('catNms',dpm_class);

for jj = 1:nImages
    
    %% load and display image
    try
        img_info = coco.loadImgs(imgIds(jj));
        img = imread(sprintf('%s/images/%s/%s',dataDir,dataType,img_info.file_name));
        
        %figure(1); imagesc(img); axis('image'); set(gca,'XTick',[],'YTick',[])
    catch
        error('Error in imgIds vector. Id [%d] not in COCO! Stopping Test.', imgIds(jj) );
    end
    
    %% run dpm code on the image
    [ds, bs] = imgdetect(img, dpm_model, dpm_thresh);

    if ~isempty(ds)
        if dpm_model.type == model_types.MixStar
            if isfield(dpm_model, 'bboxpred')
                bboxpred = dpm_model.bboxpred;
                [ds, bs] = clipboxes(img, ds, bs);
                [ds, bs] = bboxpred_get(bboxpred, ds, reduceboxes(dpm_model, bs));
            else
                warning('no bounding box predictor found');
            end
        end
        [ds, bs] = clipboxes(img, ds, bs);
        I = nms(ds, 0.5);
        ds = ds(I,:);
        bs = bs(I,:);
    end
    
    %% put the detections in COCO format
    
    nDetections = size(ds,1);
    if (nDetections > maxDetections)
        warning('Number of detections in image [%s/%d] exceeds maximum allowed (%d). Detections in excess will not be stored.', dataType, imgIds(jj), maxDetections);
        nDetections = maxDetections;
    end
    for ii = 1:nDetections
        counter = counter + 1;
        
        output(counter).image_id = imgIds(jj);
        output(counter).category_id = category_id;
        output(counter).bbox = ds(ii,1:4);
        output(counter).score = ds(ii,5);
    end
    
end

%% save detections on filesystem in JSON format and return output structure
if nargin < 6
    outputFile = strcat('./',dpm_class(~isspace(dpm_class)),'_dpm_detections_coco.json');
end

s = gason( output );

fid = fopen(outputFile, 'w');
fprintf(fid, '%s', s);
fclose(fid);


