#import "SPKBrandLogoView.h"

static UIBezierPath *SPKCreateSparkleLogoPath(CGRect rect) {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat S = MIN(rect.size.width, rect.size.height) / 2.0;

    // Subpath 1
    [path moveToPoint:CGPointMake(center.x + (-0.0242) * S, center.y + (-0.9941) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1029) * S, center.y + (-0.9650) * S)
            controlPoint1:CGPointMake(center.x + (-0.0515) * S, center.y + (-0.9912) * S)
            controlPoint2:CGPointMake(center.x + (-0.0791) * S, center.y + (-0.9810) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1662) * S, center.y + (-0.8906) * S)
            controlPoint1:CGPointMake(center.x + (-0.1288) * S, center.y + (-0.9476) * S)
            controlPoint2:CGPointMake(center.x + (-0.1517) * S, center.y + (-0.9208) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1829) * S, center.y + (-0.8419) * S)
            controlPoint1:CGPointMake(center.x + (-0.1738) * S, center.y + (-0.8750) * S)
            controlPoint2:CGPointMake(center.x + (-0.1775) * S, center.y + (-0.8642) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.2282) * S, center.y + (-0.6917) * S)
            controlPoint1:CGPointMake(center.x + (-0.1948) * S, center.y + (-0.7933) * S)
            controlPoint2:CGPointMake(center.x + (-0.2129) * S, center.y + (-0.7333) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.4085) * S, center.y + (-0.4066) * S)
            controlPoint1:CGPointMake(center.x + (-0.2690) * S, center.y + (-0.5806) * S)
            controlPoint2:CGPointMake(center.x + (-0.3286) * S, center.y + (-0.4864) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.6460) * S, center.y + (-0.2454) * S)
            controlPoint1:CGPointMake(center.x + (-0.4776) * S, center.y + (-0.3375) * S)
            controlPoint2:CGPointMake(center.x + (-0.5530) * S, center.y + (-0.2863) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.8117) * S, center.y + (-0.1900) * S)
            controlPoint1:CGPointMake(center.x + (-0.6971) * S, center.y + (-0.2228) * S)
            controlPoint2:CGPointMake(center.x + (-0.7348) * S, center.y + (-0.2102) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.9195) * S, center.y + (-0.1501) * S)
            controlPoint1:CGPointMake(center.x + (-0.8784) * S, center.y + (-0.1723) * S)
            controlPoint2:CGPointMake(center.x + (-0.8954) * S, center.y + (-0.1660) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.9597) * S, center.y + (-0.1124) * S)
            controlPoint1:CGPointMake(center.x + (-0.9318) * S, center.y + (-0.1418) * S)
            controlPoint2:CGPointMake(center.x + (-0.9499) * S, center.y + (-0.1248) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.9971) * S, center.y + (0.0107) * S)
            controlPoint1:CGPointMake(center.x + (-0.9870) * S, center.y + (-0.0773) * S)
            controlPoint2:CGPointMake(center.x + (-1.0000) * S, center.y + (-0.0347) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.9011) * S, center.y + (0.1581) * S)
            controlPoint1:CGPointMake(center.x + (-0.9931) * S, center.y + (0.0745) * S)
            controlPoint2:CGPointMake(center.x + (-0.9566) * S, center.y + (0.1305) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.8258) * S, center.y + (0.1831) * S)
            controlPoint1:CGPointMake(center.x + (-0.8827) * S, center.y + (0.1673) * S)
            controlPoint2:CGPointMake(center.x + (-0.8752) * S, center.y + (0.1697) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.6522) * S, center.y + (0.2398) * S)
            controlPoint1:CGPointMake(center.x + (-0.7341) * S, center.y + (0.2080) * S)
            controlPoint2:CGPointMake(center.x + (-0.7005) * S, center.y + (0.2189) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.3547) * S, center.y + (0.4639) * S)
            controlPoint1:CGPointMake(center.x + (-0.5321) * S, center.y + (0.2915) * S)
            controlPoint2:CGPointMake(center.x + (-0.4326) * S, center.y + (0.3665) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1867) * S, center.y + (0.8285) * S)
            controlPoint1:CGPointMake(center.x + (-0.2778) * S, center.y + (0.5602) * S)
            controlPoint2:CGPointMake(center.x + (-0.2205) * S, center.y + (0.6845) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1585) * S, center.y + (0.9026) * S)
            controlPoint1:CGPointMake(center.x + (-0.1789) * S, center.y + (0.8615) * S)
            controlPoint2:CGPointMake(center.x + (-0.1713) * S, center.y + (0.8815) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0096) * S, center.y + (0.9919) * S)
            controlPoint1:CGPointMake(center.x + (-0.1222) * S, center.y + (0.9624) * S)
            controlPoint2:CGPointMake(center.x + (-0.0552) * S, center.y + (0.9979) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0733) * S, center.y + (0.9737) * S)
            controlPoint1:CGPointMake(center.x + (0.0346) * S, center.y + (0.9895) * S)
            controlPoint2:CGPointMake(center.x + (0.0507) * S, center.y + (0.9849) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1670) * S, center.y + (0.8685) * S)
            controlPoint1:CGPointMake(center.x + (0.1159) * S, center.y + (0.9526) * S)
            controlPoint2:CGPointMake(center.x + (0.1488) * S, center.y + (0.9157) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1790) * S, center.y + (0.8262) * S)
            controlPoint1:CGPointMake(center.x + (0.1694) * S, center.y + (0.8624) * S)
            controlPoint2:CGPointMake(center.x + (0.1748) * S, center.y + (0.8434) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.2067) * S, center.y + (0.7288) * S)
            controlPoint1:CGPointMake(center.x + (0.1888) * S, center.y + (0.7864) * S)
            controlPoint2:CGPointMake(center.x + (0.1966) * S, center.y + (0.7588) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.4852) * S, center.y + (0.3304) * S)
            controlPoint1:CGPointMake(center.x + (0.2640) * S, center.y + (0.5570) * S)
            controlPoint2:CGPointMake(center.x + (0.3563) * S, center.y + (0.4250) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.7546) * S, center.y + (0.2005) * S)
            controlPoint1:CGPointMake(center.x + (0.5644) * S, center.y + (0.2725) * S)
            controlPoint2:CGPointMake(center.x + (0.6517) * S, center.y + (0.2303) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.8245) * S, center.y + (0.1814) * S)
            controlPoint1:CGPointMake(center.x + (0.7672) * S, center.y + (0.1969) * S)
            controlPoint2:CGPointMake(center.x + (0.7753) * S, center.y + (0.1946) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.8679) * S, center.y + (0.1689) * S)
            controlPoint1:CGPointMake(center.x + (0.8430) * S, center.y + (0.1764) * S)
            controlPoint2:CGPointMake(center.x + (0.8624) * S, center.y + (0.1708) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.9123) * S, center.y + (0.1464) * S)
            controlPoint1:CGPointMake(center.x + (0.8810) * S, center.y + (0.1643) * S)
            controlPoint2:CGPointMake(center.x + (0.9005) * S, center.y + (0.1544) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.9854) * S, center.y + (-0.0384) * S)
            controlPoint1:CGPointMake(center.x + (0.9713) * S, center.y + (0.1066) * S)
            controlPoint2:CGPointMake(center.x + (1.0000) * S, center.y + (0.0338) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.9363) * S, center.y + (-0.1287) * S)
            controlPoint1:CGPointMake(center.x + (0.9783) * S, center.y + (-0.0734) * S)
            controlPoint2:CGPointMake(center.x + (0.9626) * S, center.y + (-0.1024) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.8879) * S, center.y + (-0.1632) * S)
            controlPoint1:CGPointMake(center.x + (0.9201) * S, center.y + (-0.1449) * S)
            controlPoint2:CGPointMake(center.x + (0.9075) * S, center.y + (-0.1538) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.8078) * S, center.y + (-0.1888) * S)
            controlPoint1:CGPointMake(center.x + (0.8700) * S, center.y + (-0.1716) * S)
            controlPoint2:CGPointMake(center.x + (0.8620) * S, center.y + (-0.1742) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.6370) * S, center.y + (-0.2458) * S)
            controlPoint1:CGPointMake(center.x + (0.7236) * S, center.y + (-0.2112) * S)
            controlPoint2:CGPointMake(center.x + (0.6890) * S, center.y + (-0.2228) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.2715) * S, center.y + (-0.5795) * S)
            controlPoint1:CGPointMake(center.x + (0.4776) * S, center.y + (-0.3160) * S)
            controlPoint2:CGPointMake(center.x + (0.3545) * S, center.y + (-0.4285) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.2166) * S, center.y + (-0.7009) * S)
            controlPoint1:CGPointMake(center.x + (0.2525) * S, center.y + (-0.6139) * S)
            controlPoint2:CGPointMake(center.x + (0.2301) * S, center.y + (-0.6636) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1758) * S, center.y + (-0.8381) * S)
            controlPoint1:CGPointMake(center.x + (0.2038) * S, center.y + (-0.7365) * S)
            controlPoint2:CGPointMake(center.x + (0.1866) * S, center.y + (-0.7942) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1637) * S, center.y + (-0.8778) * S)
            controlPoint1:CGPointMake(center.x + (0.1702) * S, center.y + (-0.8607) * S)
            controlPoint2:CGPointMake(center.x + (0.1687) * S, center.y + (-0.8657) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1210) * S, center.y + (-0.9428) * S)
            controlPoint1:CGPointMake(center.x + (0.1537) * S, center.y + (-0.9028) * S)
            controlPoint2:CGPointMake(center.x + (0.1396) * S, center.y + (-0.9242) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0774) * S, center.y + (-0.9755) * S)
            controlPoint1:CGPointMake(center.x + (0.1052) * S, center.y + (-0.9587) * S)
            controlPoint2:CGPointMake(center.x + (0.0944) * S, center.y + (-0.9669) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.0242) * S, center.y + (-0.9941) * S)
            controlPoint1:CGPointMake(center.x + (0.0455) * S, center.y + (-0.9918) * S)
            controlPoint2:CGPointMake(center.x + (0.0118) * S, center.y + (-0.9979) * S)];
    [path closePath];

    // Subpath 2
    [path moveToPoint:CGPointMake(center.x + (-0.0017) * S, center.y + (-0.8140) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0067) * S, center.y + (-0.7869) * S)
            controlPoint1:CGPointMake(center.x + (-0.0004) * S, center.y + (-0.8130) * S)
            controlPoint2:CGPointMake(center.x + (0.0023) * S, center.y + (-0.8042) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0497) * S, center.y + (-0.6413) * S)
            controlPoint1:CGPointMake(center.x + (0.0216) * S, center.y + (-0.7272) * S)
            controlPoint2:CGPointMake(center.x + (0.0339) * S, center.y + (-0.6859) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.2316) * S, center.y + (-0.3278) * S)
            controlPoint1:CGPointMake(center.x + (0.0909) * S, center.y + (-0.5260) * S)
            controlPoint2:CGPointMake(center.x + (0.1540) * S, center.y + (-0.4173) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.3194) * S, center.y + (-0.2397) * S)
            controlPoint1:CGPointMake(center.x + (0.2485) * S, center.y + (-0.3083) * S)
            controlPoint2:CGPointMake(center.x + (0.3001) * S, center.y + (-0.2566) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.6744) * S, center.y + (-0.0427) * S)
            controlPoint1:CGPointMake(center.x + (0.4200) * S, center.y + (-0.1521) * S)
            controlPoint2:CGPointMake(center.x + (0.5432) * S, center.y + (-0.0836) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.7612) * S, center.y + (-0.0180) * S)
            controlPoint1:CGPointMake(center.x + (0.7113) * S, center.y + (-0.0312) * S)
            controlPoint2:CGPointMake(center.x + (0.7141) * S, center.y + (-0.0303) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.8075) * S, center.y + (-0.0056) * S)
            controlPoint1:CGPointMake(center.x + (0.7853) * S, center.y + (-0.0118) * S)
            controlPoint2:CGPointMake(center.x + (0.8061) * S, center.y + (-0.0062) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.8075) * S, center.y + (0.0024) * S)
            controlPoint1:CGPointMake(center.x + (0.8107) * S, center.y + (-0.0042) * S)
            controlPoint2:CGPointMake(center.x + (0.8107) * S, center.y + (0.0004) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.7681) * S, center.y + (0.0134) * S)
            controlPoint1:CGPointMake(center.x + (0.8061) * S, center.y + (0.0032) * S)
            controlPoint2:CGPointMake(center.x + (0.7884) * S, center.y + (0.0082) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.6061) * S, center.y + (0.0643) * S)
            controlPoint1:CGPointMake(center.x + (0.6957) * S, center.y + (0.0318) * S)
            controlPoint2:CGPointMake(center.x + (0.6589) * S, center.y + (0.0643) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.3476) * S, center.y + (0.2138) * S)
            controlPoint1:CGPointMake(center.x + (0.5081) * S, center.y + (0.1031) * S)
            controlPoint2:CGPointMake(center.x + (0.4267) * S, center.y + (0.1502) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1877) * S, center.y + (0.3803) * S)
            controlPoint1:CGPointMake(center.x + (0.2908) * S, center.y + (0.2594) * S)
            controlPoint2:CGPointMake(center.x + (0.2318) * S, center.y + (0.3209) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1176) * S, center.y + (0.4903) * S)
            controlPoint1:CGPointMake(center.x + (0.1657) * S, center.y + (0.4101) * S)
            controlPoint2:CGPointMake(center.x + (0.1342) * S, center.y + (0.4592) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0365) * S, center.y + (0.6806) * S)
            controlPoint1:CGPointMake(center.x + (0.0365) * S, center.y + (0.6806) * S)
            controlPoint2:CGPointMake(center.x + (0.0599) * S, center.y + (0.6091) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0035) * S, center.y + (0.7980) * S)
            controlPoint1:CGPointMake(center.x + (0.0256) * S, center.y + (0.7138) * S)
            controlPoint2:CGPointMake(center.x + (0.0113) * S, center.y + (0.7646) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0002) * S, center.y + (0.8097) * S)
            controlPoint1:CGPointMake(center.x + (0.0022) * S, center.y + (0.8032) * S)
            controlPoint2:CGPointMake(center.x + (0.0007) * S, center.y + (0.8085) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.0079) * S, center.y + (0.8092) * S)
            controlPoint1:CGPointMake(center.x + (-0.0015) * S, center.y + (0.8125) * S)
            controlPoint2:CGPointMake(center.x + (-0.0059) * S, center.y + (0.8124) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.0160) * S, center.y + (0.7803) * S)
            controlPoint1:CGPointMake(center.x + (-0.0086) * S, center.y + (0.8079) * S)
            controlPoint2:CGPointMake(center.x + (-0.0123) * S, center.y + (0.7949) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1570) * S, center.y + (0.4372) * S)
            controlPoint1:CGPointMake(center.x + (-0.0503) * S, center.y + (0.6438) * S)
            controlPoint2:CGPointMake(center.x + (-0.0952) * S, center.y + (0.5346) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.3926) * S, center.y + (0.1854) * S)
            controlPoint1:CGPointMake(center.x + (-0.2203) * S, center.y + (0.3375) * S)
            controlPoint2:CGPointMake(center.x + (-0.2975) * S, center.y + (0.2551) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.6199) * S, center.y + (0.0616) * S)
            controlPoint1:CGPointMake(center.x + (-0.4600) * S, center.y + (0.1360) * S)
            controlPoint2:CGPointMake(center.x + (-0.5329) * S, center.y + (0.0963) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.7624) * S, center.y + (0.0171) * S)
            controlPoint1:CGPointMake(center.x + (-0.6551) * S, center.y + (0.0475) * S)
            controlPoint2:CGPointMake(center.x + (-0.7080) * S, center.y + (0.0311) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.8167) * S, center.y + (0.0019) * S)
            controlPoint1:CGPointMake(center.x + (-0.8107) * S, center.y + (0.0046) * S)
            controlPoint2:CGPointMake(center.x + (-0.8149) * S, center.y + (0.0034) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.8157) * S, center.y + (-0.0049) * S)
            controlPoint1:CGPointMake(center.x + (-0.8190) * S, center.y + (0.0001) * S)
            controlPoint2:CGPointMake(center.x + (-0.8185) * S, center.y + (-0.0032) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.7692) * S, center.y + (-0.0179) * S)
            controlPoint1:CGPointMake(center.x + (-0.8144) * S, center.y + (-0.0058) * S)
            controlPoint2:CGPointMake(center.x + (-0.7935) * S, center.y + (-0.0117) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.6681) * S, center.y + (-0.0472) * S)
            controlPoint1:CGPointMake(center.x + (-0.7210) * S, center.y + (-0.0305) * S)
            controlPoint2:CGPointMake(center.x + (-0.6995) * S, center.y + (-0.0367) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.3798) * S, center.y + (-0.1979) * S)
            controlPoint1:CGPointMake(center.x + (-0.5609) * S, center.y + (-0.0832) * S)
            controlPoint2:CGPointMake(center.x + (-0.4677) * S, center.y + (-0.1319) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1319) * S, center.y + (-0.4804) * S)
            controlPoint1:CGPointMake(center.x + (-0.2791) * S, center.y + (-0.2734) * S)
            controlPoint2:CGPointMake(center.x + (-0.1940) * S, center.y + (-0.3703) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.0161) * S, center.y + (-0.7817) * S)
            controlPoint1:CGPointMake(center.x + (-0.0799) * S, center.y + (-0.5723) * S)
            controlPoint2:CGPointMake(center.x + (-0.0470) * S, center.y + (-0.6581) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.0068) * S, center.y + (-0.8137) * S)
            controlPoint1:CGPointMake(center.x + (-0.0084) * S, center.y + (-0.8125) * S)
            controlPoint2:CGPointMake(center.x + (-0.0086) * S, center.y + (-0.8117) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.0017) * S, center.y + (-0.8140) * S)
            controlPoint1:CGPointMake(center.x + (-0.0047) * S, center.y + (-0.8156) * S)
            controlPoint2:CGPointMake(center.x + (-0.0041) * S, center.y + (-0.8157) * S)];
    [path closePath];

    return path;
}

static UIBezierPath *SPKCreateSparkleSolidPath(CGRect rect) {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat S = MIN(rect.size.width, rect.size.height) / 2.0;

    [path moveToPoint:CGPointMake(center.x + (-0.0242) * S, center.y + (-0.9941) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1029) * S, center.y + (-0.9650) * S)
            controlPoint1:CGPointMake(center.x + (-0.0515) * S, center.y + (-0.9912) * S)
            controlPoint2:CGPointMake(center.x + (-0.0791) * S, center.y + (-0.9810) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1662) * S, center.y + (-0.8906) * S)
            controlPoint1:CGPointMake(center.x + (-0.1288) * S, center.y + (-0.9476) * S)
            controlPoint2:CGPointMake(center.x + (-0.1517) * S, center.y + (-0.9208) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1829) * S, center.y + (-0.8419) * S)
            controlPoint1:CGPointMake(center.x + (-0.1738) * S, center.y + (-0.8750) * S)
            controlPoint2:CGPointMake(center.x + (-0.1775) * S, center.y + (-0.8642) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.2282) * S, center.y + (-0.6917) * S)
            controlPoint1:CGPointMake(center.x + (-0.1948) * S, center.y + (-0.7933) * S)
            controlPoint2:CGPointMake(center.x + (-0.2129) * S, center.y + (-0.7333) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.4085) * S, center.y + (-0.4066) * S)
            controlPoint1:CGPointMake(center.x + (-0.2690) * S, center.y + (-0.5806) * S)
            controlPoint2:CGPointMake(center.x + (-0.3286) * S, center.y + (-0.4864) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.6460) * S, center.y + (-0.2454) * S)
            controlPoint1:CGPointMake(center.x + (-0.4776) * S, center.y + (-0.3375) * S)
            controlPoint2:CGPointMake(center.x + (-0.5530) * S, center.y + (-0.2863) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.8117) * S, center.y + (-0.1900) * S)
            controlPoint1:CGPointMake(center.x + (-0.6971) * S, center.y + (-0.2228) * S)
            controlPoint2:CGPointMake(center.x + (-0.7348) * S, center.y + (-0.2102) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.9195) * S, center.y + (-0.1501) * S)
            controlPoint1:CGPointMake(center.x + (-0.8784) * S, center.y + (-0.1723) * S)
            controlPoint2:CGPointMake(center.x + (-0.8954) * S, center.y + (-0.1660) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.9597) * S, center.y + (-0.1124) * S)
            controlPoint1:CGPointMake(center.x + (-0.9318) * S, center.y + (-0.1418) * S)
            controlPoint2:CGPointMake(center.x + (-0.9499) * S, center.y + (-0.1248) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.9971) * S, center.y + (0.0107) * S)
            controlPoint1:CGPointMake(center.x + (-0.9870) * S, center.y + (-0.0773) * S)
            controlPoint2:CGPointMake(center.x + (-1.0000) * S, center.y + (-0.0347) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.9011) * S, center.y + (0.1581) * S)
            controlPoint1:CGPointMake(center.x + (-0.9931) * S, center.y + (0.0745) * S)
            controlPoint2:CGPointMake(center.x + (-0.9566) * S, center.y + (0.1305) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.8258) * S, center.y + (0.1831) * S)
            controlPoint1:CGPointMake(center.x + (-0.8827) * S, center.y + (0.1673) * S)
            controlPoint2:CGPointMake(center.x + (-0.8752) * S, center.y + (0.1697) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.6522) * S, center.y + (0.2398) * S)
            controlPoint1:CGPointMake(center.x + (-0.7341) * S, center.y + (0.2080) * S)
            controlPoint2:CGPointMake(center.x + (-0.7005) * S, center.y + (0.2189) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.3547) * S, center.y + (0.4639) * S)
            controlPoint1:CGPointMake(center.x + (-0.5321) * S, center.y + (0.2915) * S)
            controlPoint2:CGPointMake(center.x + (-0.4326) * S, center.y + (0.3665) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1867) * S, center.y + (0.8285) * S)
            controlPoint1:CGPointMake(center.x + (-0.2778) * S, center.y + (0.5602) * S)
            controlPoint2:CGPointMake(center.x + (-0.2205) * S, center.y + (0.6845) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.1585) * S, center.y + (0.9026) * S)
            controlPoint1:CGPointMake(center.x + (-0.1789) * S, center.y + (0.8615) * S)
            controlPoint2:CGPointMake(center.x + (-0.1713) * S, center.y + (0.8815) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0096) * S, center.y + (0.9919) * S)
            controlPoint1:CGPointMake(center.x + (-0.1222) * S, center.y + (0.9624) * S)
            controlPoint2:CGPointMake(center.x + (-0.0552) * S, center.y + (0.9979) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0733) * S, center.y + (0.9737) * S)
            controlPoint1:CGPointMake(center.x + (0.0346) * S, center.y + (0.9895) * S)
            controlPoint2:CGPointMake(center.x + (0.0507) * S, center.y + (0.9849) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1670) * S, center.y + (0.8685) * S)
            controlPoint1:CGPointMake(center.x + (0.1159) * S, center.y + (0.9526) * S)
            controlPoint2:CGPointMake(center.x + (0.1488) * S, center.y + (0.9157) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1790) * S, center.y + (0.8262) * S)
            controlPoint1:CGPointMake(center.x + (0.1694) * S, center.y + (0.8624) * S)
            controlPoint2:CGPointMake(center.x + (0.1748) * S, center.y + (0.8434) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.2067) * S, center.y + (0.7288) * S)
            controlPoint1:CGPointMake(center.x + (0.1888) * S, center.y + (0.7864) * S)
            controlPoint2:CGPointMake(center.x + (0.1966) * S, center.y + (0.7588) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.4852) * S, center.y + (0.3304) * S)
            controlPoint1:CGPointMake(center.x + (0.2640) * S, center.y + (0.5570) * S)
            controlPoint2:CGPointMake(center.x + (0.3563) * S, center.y + (0.4250) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.7546) * S, center.y + (0.2005) * S)
            controlPoint1:CGPointMake(center.x + (0.5644) * S, center.y + (0.2725) * S)
            controlPoint2:CGPointMake(center.x + (0.6517) * S, center.y + (0.2303) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.8245) * S, center.y + (0.1814) * S)
            controlPoint1:CGPointMake(center.x + (0.7672) * S, center.y + (0.1969) * S)
            controlPoint2:CGPointMake(center.x + (0.7753) * S, center.y + (0.1946) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.8679) * S, center.y + (0.1689) * S)
            controlPoint1:CGPointMake(center.x + (0.8430) * S, center.y + (0.1764) * S)
            controlPoint2:CGPointMake(center.x + (0.8624) * S, center.y + (0.1708) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.9123) * S, center.y + (0.1464) * S)
            controlPoint1:CGPointMake(center.x + (0.8810) * S, center.y + (0.1643) * S)
            controlPoint2:CGPointMake(center.x + (0.9005) * S, center.y + (0.1544) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.9854) * S, center.y + (-0.0384) * S)
            controlPoint1:CGPointMake(center.x + (0.9713) * S, center.y + (0.1066) * S)
            controlPoint2:CGPointMake(center.x + (1.0000) * S, center.y + (0.0338) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.9363) * S, center.y + (-0.1287) * S)
            controlPoint1:CGPointMake(center.x + (0.9783) * S, center.y + (-0.0734) * S)
            controlPoint2:CGPointMake(center.x + (0.9626) * S, center.y + (-0.1024) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.8879) * S, center.y + (-0.1632) * S)
            controlPoint1:CGPointMake(center.x + (0.9201) * S, center.y + (-0.1449) * S)
            controlPoint2:CGPointMake(center.x + (0.9075) * S, center.y + (-0.1538) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.8078) * S, center.y + (-0.1888) * S)
            controlPoint1:CGPointMake(center.x + (0.8700) * S, center.y + (-0.1716) * S)
            controlPoint2:CGPointMake(center.x + (0.8620) * S, center.y + (-0.1742) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.6370) * S, center.y + (-0.2458) * S)
            controlPoint1:CGPointMake(center.x + (0.7236) * S, center.y + (-0.2112) * S)
            controlPoint2:CGPointMake(center.x + (0.6890) * S, center.y + (-0.2228) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.2715) * S, center.y + (-0.5795) * S)
            controlPoint1:CGPointMake(center.x + (0.4776) * S, center.y + (-0.3160) * S)
            controlPoint2:CGPointMake(center.x + (0.3545) * S, center.y + (-0.4285) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.2166) * S, center.y + (-0.7009) * S)
            controlPoint1:CGPointMake(center.x + (0.2525) * S, center.y + (-0.6139) * S)
            controlPoint2:CGPointMake(center.x + (0.2301) * S, center.y + (-0.6636) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1758) * S, center.y + (-0.8381) * S)
            controlPoint1:CGPointMake(center.x + (0.2038) * S, center.y + (-0.7365) * S)
            controlPoint2:CGPointMake(center.x + (0.1866) * S, center.y + (-0.7942) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1637) * S, center.y + (-0.8778) * S)
            controlPoint1:CGPointMake(center.x + (0.1702) * S, center.y + (-0.8607) * S)
            controlPoint2:CGPointMake(center.x + (0.1687) * S, center.y + (-0.8657) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.1210) * S, center.y + (-0.9428) * S)
            controlPoint1:CGPointMake(center.x + (0.1537) * S, center.y + (-0.9028) * S)
            controlPoint2:CGPointMake(center.x + (0.1396) * S, center.y + (-0.9242) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (0.0774) * S, center.y + (-0.9755) * S)
            controlPoint1:CGPointMake(center.x + (0.1052) * S, center.y + (-0.9587) * S)
            controlPoint2:CGPointMake(center.x + (0.0944) * S, center.y + (-0.9669) * S)];
    [path addCurveToPoint:CGPointMake(center.x + (-0.0242) * S, center.y + (-0.9941) * S)
            controlPoint1:CGPointMake(center.x + (0.0455) * S, center.y + (-0.9918) * S)
            controlPoint2:CGPointMake(center.x + (0.0118) * S, center.y + (-0.9979) * S)];
    [path closePath];

    return path;
}

@interface SPKBrandLogoView ()
@property (nonatomic, strong) CAShapeLayer *mainStarLayer;
@property (nonatomic, strong) CAShapeLayer *smallStarLeftLayer;
@property (nonatomic, strong) CAShapeLayer *smallStarRightLayer;
@end

@implementation SPKBrandLogoView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;

        _mainStarContainer = [[UIView alloc] initWithFrame:self.bounds];
        _mainStarContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_mainStarContainer];

        _flankingStarsContainer = [[UIView alloc] initWithFrame:self.bounds];
        _flankingStarsContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_flankingStarsContainer];

        _mainStarLayer = [CAShapeLayer layer];
        _mainStarLayer.fillColor = UIColor.whiteColor.CGColor;
        _mainStarLayer.shadowColor = UIColor.whiteColor.CGColor;
        _mainStarLayer.shadowOffset = CGSizeZero;
        _mainStarLayer.shadowRadius = 8.0;
        _mainStarLayer.shadowOpacity = 0.85;
        [_mainStarContainer.layer addSublayer:_mainStarLayer];

        _smallStarLeftLayer = [CAShapeLayer layer];
        _smallStarLeftLayer.fillColor = [UIColor.whiteColor colorWithAlphaComponent:0.8].CGColor;
        _smallStarLeftLayer.shadowColor = UIColor.whiteColor.CGColor;
        _smallStarLeftLayer.shadowOffset = CGSizeZero;
        _smallStarLeftLayer.shadowRadius = 3.0;
        _smallStarLeftLayer.shadowOpacity = 0.6;
        [_flankingStarsContainer.layer addSublayer:_smallStarLeftLayer];

        _smallStarRightLayer = [CAShapeLayer layer];
        _smallStarRightLayer.fillColor = [UIColor.whiteColor colorWithAlphaComponent:0.9].CGColor;
        _smallStarRightLayer.shadowColor = UIColor.whiteColor.CGColor;
        _smallStarRightLayer.shadowOffset = CGSizeZero;
        _smallStarRightLayer.shadowRadius = 4.0;
        _smallStarRightLayer.shadowOpacity = 0.7;
        [_flankingStarsContainer.layer addSublayer:_smallStarRightLayer];

        [self startAnimating];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat S = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0;

    // 80pt size for 116pt bounds (68.96%). Let's use 80pt!
    CGFloat mainStarRadius = S * (78.0 / 116.0);

    CGRect mainRect = CGRectMake(center.x - mainStarRadius, center.y - mainStarRadius, mainStarRadius * 2.0, mainStarRadius * 2.0);
    self.mainStarLayer.path = SPKCreateSparkleLogoPath(mainRect).CGPath;
    self.mainStarLayer.frame = self.bounds;

    // Center Left Twinkle at dx = -35, dy = 35 relative to main star center (diagonal)
    CGFloat leftSize = S * (16.0 / 58.0);
    CGFloat leftDx = -S * (35.0 / 58.0);
    CGFloat leftDy = S * (35.0 / 58.0);
    CGRect leftRect = CGRectMake(center.x + leftDx - leftSize / 2.0, center.y + leftDy - leftSize / 2.0, leftSize, leftSize);
    self.smallStarLeftLayer.path = SPKCreateSparkleSolidPath(leftRect).CGPath;
    self.smallStarLeftLayer.frame = self.bounds;

    // Center Right Twinkle at dx = 35, dy = -35 relative to main star center (diagonal)
    CGFloat rightSize = S * (20.0 / 58.0);
    CGFloat rightDx = S * (35.0 / 58.0);
    CGFloat rightDy = -S * (35.0 / 58.0);
    CGRect rightRect = CGRectMake(center.x + rightDx - rightSize / 2.0, center.y + rightDy - rightSize / 2.0, rightSize, rightSize);
    self.smallStarRightLayer.path = SPKCreateSparkleSolidPath(rightRect).CGPath;
    self.smallStarRightLayer.frame = self.bounds;
}

- (void)startAnimating {
    [self stopAnimating];

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @0.94;
    pulse.toValue = @1.06;
    pulse.duration = 2.4;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.mainStarLayer addAnimation:pulse forKey:@"pulse"];

    CABasicAnimation *swing = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    swing.fromValue = @(-0.04);
    swing.toValue = @0.04;
    swing.duration = 3.6;
    swing.autoreverses = YES;
    swing.repeatCount = HUGE_VALF;
    swing.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.mainStarLayer addAnimation:swing forKey:@"swing"];

    CABasicAnimation *twinkleL = [CABasicAnimation animationWithKeyPath:@"opacity"];
    twinkleL.fromValue = @0.35;
    twinkleL.toValue = @0.85;
    twinkleL.duration = 1.6;
    twinkleL.autoreverses = YES;
    twinkleL.repeatCount = HUGE_VALF;
    twinkleL.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.smallStarLeftLayer addAnimation:twinkleL forKey:@"twinkle"];

    CABasicAnimation *twinkleR = [CABasicAnimation animationWithKeyPath:@"opacity"];
    twinkleR.fromValue = @0.45;
    twinkleR.toValue = @1.0;
    twinkleR.duration = 2.2;
    twinkleR.autoreverses = YES;
    twinkleR.repeatCount = HUGE_VALF;
    twinkleR.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.smallStarRightLayer addAnimation:twinkleR forKey:@"twinkle"];
}

- (void)stopAnimating {
    [self.mainStarLayer removeAllAnimations];
    [self.smallStarLeftLayer removeAllAnimations];
    [self.smallStarRightLayer removeAllAnimations];
}

- (void)setScrollProgress:(CGFloat)progress {
    CGAffineTransform rot = CGAffineTransformMakeRotation(progress * M_PI_2);
    self.mainStarContainer.transform = rot;
    self.flankingStarsContainer.transform = rot;

    CGFloat smallOpacity = 1.0;
    if (progress <= 1.0) {
        smallOpacity = 1.0 - progress * 0.7;
    } else {
        smallOpacity = 0.3 + (progress - 1.0) * 0.7;
    }
    self.flankingStarsContainer.alpha = smallOpacity;
}

@end
