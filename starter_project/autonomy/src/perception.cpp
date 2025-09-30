#include "perception.hpp"
#include "mrover/msg/detail/starter_project_tag__struct.hpp"

// ROS Headers, ros namespace
#include <cmath>
#include <functional>
#include <iterator>
#include <limits>
#include <memory>
#include <numeric>
#include <opencv2/aruco.hpp>
#include <opencv2/core.hpp>
#include <opencv2/core/cvstd_wrapper.hpp>
#include <opencv2/core/mat.hpp>
#include <opencv2/core/types.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <utility>
#include <vector>

auto main(int argc, char** argv) -> int {
    rclcpp::init(argc, argv);

    // "spin" blocks until our node dies
    rclcpp::spin(std::make_shared<mrover::Perception>());
    rclcpp::shutdown();

    return EXIT_SUCCESS;
}

namespace mrover {

    Perception::Perception() : Node("perception") {
        // Subscribe to camera image messages
        // Every time another node publishes to this topic we will be notified
        // Specifically the callback we passed will be invoked
        mImageSubscriber = create_subscription<sensor_msgs::msg::Image>("zed/left/image", 1, [this](sensor_msgs::msg::Image::ConstSharedPtr const& msg) {
            imageCallback(msg);
        });

        // Create a publisher for our tag topic
        // See: http://wiki.ros.org/ROS/Tutorials/WritingPublisherSubscriber%28c%2B%2B%29
        // TODO: uncomment me!
        mTagPublisher = create_publisher<msg::StarterProjectTag>("tag", 1);

        mTagDictionary = cv::makePtr<cv::aruco::Dictionary>(cv::aruco::getPredefinedDictionary(cv::aruco::DICT_4X4_50));
    }

    auto Perception::imageCallback(sensor_msgs::msg::Image::ConstSharedPtr const& imageMessage) -> void {
        // Create a cv::Mat from the ROS image message
        // Note this does not copy the image data, it is basically a pointer
        // Be careful if you extend its lifetime beyond this function
        cv::Mat imageBGRA{static_cast<int>(imageMessage->height), static_cast<int>(imageMessage->width),
                      CV_8UC4, const_cast<uint8_t*>(imageMessage->data.data())};
        cv::Mat image;

        cv::cvtColor(imageBGRA, image, cv::COLOR_BGRA2BGR);
        
        findTagsInImage(image, mTags);
        if(mTags.size() >= 1) publishTag(selectTag(image, mTags));

        (void)this;
    }

    auto Perception::findTagsInImage(cv::Mat const& image, std::vector<msg::StarterProjectTag>& tags) -> void { // NOLINT(*-convert-member-functions-to-static)
        // hint: take a look at OpenCV's documentation for the detectMarkers function
        // hint: you have mTagDictionary, mTagCorners, and mTagIds member variables already defined! (look in perception.hpp)
        // hint: write and use the "getCenterFromTagCorners" and "getClosenessMetricFromTagCorners" functions
        tags.clear(); // Clear old tags in output vector

        cv::aruco::detectMarkers(image, mTagDictionary, mTagCorners, mTagIds);
        for(size_t i = 0; i < mTagCorners.size(); ++i) {
            std::pair<float, float> center = getCenterFromTagCorners(mTagCorners[i], image.rows, image.cols);

            msg::StarterProjectTag current_tag = msg::StarterProjectTag();
            current_tag.tag_id = mTagIds[i];
            current_tag.x_tag_center_pixel = center.first;
            current_tag.y_tag_center_pixel = center.second;
            current_tag.closeness_metric = getClosenessMetricFromTagCorners(image, mTagCorners[i]);

            tags.push_back(current_tag);
        }
    }

    // tags.size() >= 1
    auto Perception::selectTag(cv::Mat const& image, std::vector<msg::StarterProjectTag> const& tags) -> msg::StarterProjectTag { // NOLINT(*-convert-member-functions-to-static)
        float min_closeness = std::numeric_limits<float>::max();
        size_t min_idx = 0;

        for(size_t i = 0; i < tags.size(); ++i) {
            if(tags[i].closeness_metric < min_closeness) {
                min_closeness = tags[i].closeness_metric;
                min_idx = i;
            }
        }
        return tags[min_idx];
    }

    auto Perception::publishTag(msg::StarterProjectTag const& tag) -> void {
        mTagPublisher->publish(tag);
    }

    auto Perception::getClosenessMetricFromTagCorners(cv::Mat const& image, std::vector<cv::Point2f> const& tagCorners) -> float { // NOLINT(*-convert-member-functions-to-static)
        // hint: think about how you can use the "image" parameter
        // hint: this is an approximation that will be used later by navigation to stop "close enough" to a tag.
        // hint: try not overthink, this metric does not have to be perfectly accurate, just correlated to distance away from a tag

        float side_d = std::sqrt(std::pow(tagCorners[0].x - tagCorners[3].x, 2.0) + std::pow(tagCorners[0].y - tagCorners[3].y, 2.0));
        return side_d / image.cols;
    }

    // NOTE: changed to scale from 0 to 1
    auto Perception::getCenterFromTagCorners(std::vector<cv::Point2f> const& tagCorners, int rows, int cols) -> std::pair<float, float> { // NOLINT(*-convert-member-functions-to-static)
        float x_c = (tagCorners[0].x + tagCorners[1].x + tagCorners[2].x + tagCorners[3].x) / (4.0 * cols);
        float y_c = (tagCorners[0].y + tagCorners[1].y + tagCorners[2].y + tagCorners[3].y) / (4.0 * rows);
        return {x_c, y_c};
    }

} // namespace mrover