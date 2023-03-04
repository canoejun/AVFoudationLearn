
@protocol THFaceDetectionDelegate <NSObject>

- (void)didDetectFaces:(NSArray<AVMetadataObject *> *)faces;

@end
